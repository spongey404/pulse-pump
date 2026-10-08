import Testing
import Foundation
@testable import PulsePump

struct RootGateRoutingTests {
    private let me = Fixtures.user(uid: "me")

    private func route(_ auth: AuthState, owner: String? = nil, local: Bool = false,
                       cloud: CloudProfileStatus = .unknown, restored: Bool = false) -> RootRoute {
        RootGate.route(auth: auth, localOwnerUid: owner, hasLocalUser: local, cloud: cloud, restoreComplete: restored)
    }

    @Test func unknownAuthIsAlwaysSplash() {
        for local in [true, false] {
            for cloud in [CloudProfileStatus.unknown, .exists, .absent, .unreachable] {
                #expect(route(.unknown, owner: "me", local: local, cloud: cloud) == .splash)
            }
        }
    }

    @Test func signedOutAlwaysShowsSignIn() {
        for local in [true, false] {
            #expect(route(.signedOut, owner: "me", local: local, cloud: .exists) == .signIn)
        }
    }

    @Test func signedInWithLocalUserOpensTheAppWhateverTheCloudSays() {
        for cloud in [CloudProfileStatus.unknown, .exists, .absent, .unreachable] {
            #expect(route(.signedIn(me), owner: "me", local: true, cloud: cloud) == .main)
        }
    }

    @Test func storeCreatedBeforeAccountsIsKept() {
        #expect(route(.signedIn(me), owner: nil, local: true) == .main)
    }

    @Test func differentUidWipesFirst() {
        for local in [true, false] {
            for cloud in [CloudProfileStatus.unknown, .exists, .absent] {
                #expect(route(.signedIn(me), owner: "someone-else", local: local, cloud: cloud) == .wipeLocalStore)
            }
        }
    }

    @Test func newAccountGoesToOnboarding() {
        #expect(route(.signedIn(me), owner: nil, local: false, cloud: .absent) == .onboarding)
    }

    @Test func waitsForTheCloudCheckBeforeDeciding() {
        #expect(route(.signedIn(me), local: false, cloud: .unknown) == .splash)
    }

    @Test func returningUserOnNewDeviceRestoresInsteadOfOnboarding() {
        #expect(route(.signedIn(me), local: false, cloud: .exists, restored: false) == .restoring)
        #expect(route(.signedIn(me), local: false, cloud: .exists, restored: true) == .restoreFailed)
    }

    @Test func offlineFirstLaunchWithoutDataShowsRetry() {
        #expect(route(.signedIn(me), local: false, cloud: .unreachable) == .offlineRetry)
    }
}

@MainActor
struct AccountGateTests {
    private func make(user: AuthUser? = Fixtures.user(uid: "me"), owner: String? = nil, restored: Bool = false)
        -> (AccountGate, FakeProfileRemote, RecordingLifecycle, FakeRestoreGate, AuthSession) {
        let log = EventLog()
        let provider = FakeAuthProvider(current: user, log: log)
        let lifecycle = RecordingLifecycle(owner: owner, log: log)
        let session = AuthSession(provider: provider, lifecycle: lifecycle)
        session.start()
        let remote = FakeProfileRemote()
        let restore = FakeRestoreGate(complete: restored)
        return (AccountGate(session: session, remote: remote, lifecycle: lifecycle, restoreGate: restore),
                remote, lifecycle, restore, session)
    }

    @Test func differentAccountWipesTheStoreThenChecksCloud() async {
        let (gate, remote, lifecycle, _, _) = make(owner: "previous-user")
        remote.existingProfiles = ["me"]
        #expect(gate.route(hasLocalUser: true) == .wipeLocalStore)
        await gate.reconcile(hasLocalUser: true)
        #expect(lifecycle.wipeCount == 1)
        #expect(gate.localOwnerUid == nil)
        // The local user is gone now; the next pass checks the cloud.
        await gate.reconcile(hasLocalUser: false)
        #expect(gate.route(hasLocalUser: false) == .restoring)
    }

    @Test func existingLocalStoreIsClaimedForTheSignedInUser() async {
        let (gate, _, lifecycle, _, _) = make(owner: nil)
        await gate.reconcile(hasLocalUser: true)
        #expect(lifecycle.claims == ["me"])
        #expect(gate.route(hasLocalUser: true) == .main)
    }

    @Test func newAccountRoutesToOnboardingWithoutRestore() async {
        let (gate, _, _, restore, _) = make()
        await gate.reconcile(hasLocalUser: false)
        #expect(gate.route(hasLocalUser: false) == .onboarding)
        #expect(restore.began.isEmpty)
    }

    @Test func returningUserRestoresAndNeverWritesAProfile() async {
        let (gate, remote, _, restore, _) = make()
        remote.existingProfiles = ["me"]
        await gate.reconcile(hasLocalUser: false)
        await gate.reconcile(hasLocalUser: false)   // repeated passes must not restart the restore
        #expect(gate.route(hasLocalUser: false) == .restoring)
        #expect(restore.began == ["me"])
        #expect(remote.createdProfiles.isEmpty)          // nothing overwritten
        #expect(remote.renames.isEmpty)
        restore.complete = true
        await gate.waitForRestore()
        #expect(gate.route(hasLocalUser: true) == .main)
        #expect(remote.createdProfiles.isEmpty)
    }

    @Test func offlineThenRetrySucceeds() async {
        let (gate, remote, _, _, _) = make()
        remote.existsError = ProfileRemoteError.offline
        await gate.reconcile(hasLocalUser: false)
        #expect(gate.route(hasLocalUser: false) == .offlineRetry)
        remote.existsError = nil
        await gate.retry(hasLocalUser: false)
        #expect(gate.route(hasLocalUser: false) == .onboarding)
    }

    @Test func offlineLaunchWithLocalDataNeverTouchesTheNetwork() async {
        let (gate, remote, _, _, _) = make(owner: "me")
        remote.existsError = ProfileRemoteError.offline
        await gate.reconcile(hasLocalUser: true)
        #expect(gate.route(hasLocalUser: true) == .main)
    }

    @Test func signingOutResetsTheGate() async {
        let (gate, remote, _, _, session) = make()
        remote.existingProfiles = ["me"]
        await gate.reconcile(hasLocalUser: false)
        await session.signOut()
        await gate.reconcile(hasLocalUser: false)
        #expect(gate.cloud == .unknown)
        #expect(gate.route(hasLocalUser: false) == .signIn)
    }

    @Test func accountCreatedClaimsTheStore() {
        let (gate, _, lifecycle, _, _) = make()
        gate.accountCreated(uid: "me")
        #expect(lifecycle.claims == ["me"])
        #expect(gate.route(hasLocalUser: true) == .main)
    }
}
