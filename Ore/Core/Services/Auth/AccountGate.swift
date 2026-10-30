import Foundation
import Observation

enum CloudProfileStatus: Equatable {
    case unknown        // not checked yet
    case exists         // users/{uid} exists
    case absent         // signed in, nothing in the cloud: new account
    case unreachable    // check failed (offline)
}

enum RootRoute: Equatable {
    case splash
    case signIn
    /// Signed in as someone other than the local store's owner: wipe first.
    case wipeLocalStore
    case onboarding
    /// Cloud profile exists but nothing local yet: wait for the initial pull.
    case restoring
    /// The pull finished but produced no local user.
    case restoreFailed
    /// Signed in, no local data and the cloud could not be reached.
    case offlineRetry
    case main
}

/// The routing matrix as a pure function.
enum RootGate {
    static func route(auth: AuthState,
                      localOwnerUid: String?,
                      hasLocalUser: Bool,
                      cloud: CloudProfileStatus,
                      restoreComplete: Bool) -> RootRoute {
        switch auth {
        case .unknown:
            return .splash
        case .signedOut:
            return .signIn
        case .signedIn(let user):
            if let owner = localOwnerUid, owner != user.uid { return .wipeLocalStore }
            if hasLocalUser { return .main }
            switch cloud {
            case .unknown: return .splash
            case .absent: return .onboarding
            case .unreachable: return .offlineRetry
            case .exists: return restoreComplete ? .restoreFailed : .restoring
            }
        }
    }
}

/// Drives the gate's side effects: cloud-profile check, wipe on account switch, claiming the local store.
@MainActor
@Observable
final class AccountGate {
    private(set) var cloud: CloudProfileStatus = .unknown
    private(set) var localOwnerUid: String?
    private(set) var restoreComplete: Bool

    @ObservationIgnored let session: AuthSession
    @ObservationIgnored let remote: ProfileRemote
    @ObservationIgnored let lifecycle: SyncLifecycle
    @ObservationIgnored let restoreGate: RestoreGate
    @ObservationIgnored private var checkedUid: String?
    @ObservationIgnored private var restoreStartedFor: String?

    init(session: AuthSession, remote: ProfileRemote, lifecycle: SyncLifecycle, restoreGate: RestoreGate) {
        self.session = session
        self.remote = remote
        self.lifecycle = lifecycle
        self.restoreGate = restoreGate
        self.localOwnerUid = lifecycle.localOwnerUid
        self.restoreComplete = restoreGate.isInitialSyncComplete
    }

    func route(hasLocalUser: Bool) -> RootRoute {
        if session.isTearingDown { return .splash }
        return RootGate.route(auth: session.state, localOwnerUid: localOwnerUid, hasLocalUser: hasLocalUser,
                              cloud: cloud, restoreComplete: restoreComplete)
    }

    /// Call whenever auth state or the presence of a local user changes. Performs whatever the current route needs.
    func reconcile(hasLocalUser: Bool) async {
        guard let user = session.user else {
            cloud = .unknown
            checkedUid = nil
            restoreStartedFor = nil
            return
        }
        localOwnerUid = lifecycle.localOwnerUid

        if let owner = localOwnerUid, owner != user.uid {
            await lifecycle.wipeLocalData()
            localOwnerUid = lifecycle.localOwnerUid
            cloud = .unknown
            checkedUid = nil
            return
        }
        if hasLocalUser {
            // Normal launch, or a store created before accounts existed: it now belongs to this account.
            if localOwnerUid != user.uid {
                lifecycle.claimLocalStore(for: user.uid)
                localOwnerUid = user.uid
            }
            return
        }
        if checkedUid != user.uid || cloud == .unknown || cloud == .unreachable {
            await checkCloud(uid: user.uid)
        }
    }

    /// Re-run the cloud check (offline retry, restore retry).
    func retry(hasLocalUser: Bool) async {
        checkedUid = nil
        restoreStartedFor = nil
        cloud = .unknown
        restoreComplete = restoreGate.isInitialSyncComplete
        await reconcile(hasLocalUser: hasLocalUser)
    }

    private func checkCloud(uid: String) async {
        do {
            let exists = try await remote.cloudProfileExists(uid: uid)
            guard session.user?.uid == uid else { return }
            checkedUid = uid
            cloud = exists ? .exists : .absent
            if exists, restoreStartedFor != uid {
                restoreStartedFor = uid
                restoreGate.beginRestore(uid: uid)
            }
            restoreComplete = restoreGate.isInitialSyncComplete
        } catch {
            guard session.user?.uid == uid else { return }
            cloud = .unreachable
        }
    }

    /// Polls the restore gate while the "Restoring your data" screen is up.
    func waitForRestore() async {
        while !Task.isCancelled, !restoreGate.isInitialSyncComplete {
            try? await Task.sleep(for: .milliseconds(400))
        }
        restoreComplete = restoreGate.isInitialSyncComplete
    }

    /// Onboarding finished creating the account: the local store is this user's, and the cloud profile exists.
    func accountCreated(uid: String) {
        lifecycle.claimLocalStore(for: uid)
        localOwnerUid = uid
        checkedUid = uid
        cloud = .exists
    }
}
