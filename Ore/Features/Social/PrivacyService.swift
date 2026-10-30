import Foundation
import Observation

/// The four privacy rows, persisted three ways:
/// 1. locally (`UserDefaults`, read synchronously by the post builder and the Settings rows);
/// 2. at `users/{uid}.privacy` (only that map is written), so a new device gets them back;
/// 3. mirrored to `profiles/{uid}.profileVisibility` / `globalLeaderboardVisible`, which the security
///    rules and Cloud Functions enforce against other users.
///
/// Changing a row also affects *new* posts only: each post carries the `audience` and
/// `bodyMapAudience` captured when it was published.
@MainActor
@Observable
final class PrivacyService {
    private(set) var settings: PrivacySettings
    /// Set when the last attempt to save to Firestore failed; the change is kept locally and retried.
    private(set) var needsPush: Bool
    private(set) var lastError: String?

    @ObservationIgnored private let remote: SocialRemote
    @ObservationIgnored private let me: CurrentUser
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let displayName: () -> String
    @ObservationIgnored private static let pendingKey = "privacy_pendingPush"

    init(remote: SocialRemote, me: CurrentUser, defaults: UserDefaults = .standard, displayName: @escaping () -> String = { "Pump user" }) {
        self.remote = remote
        self.me = me
        self.defaults = defaults
        self.displayName = displayName
        self.settings = PrivacySettings.load(defaults: defaults)
        self.needsPush = defaults.bool(forKey: Self.pendingKey)
    }

    func level(for row: PrivacyRow) -> PrivacyLevel { settings[row] }

    /// Applies a change locally at once, then saves it.
    func set(_ row: PrivacyRow, to level: PrivacyLevel) async {
        var updated = settings
        updated[row] = level
        guard updated != settings else { return }
        settings = updated
        updated.save(to: defaults)
        await push()
    }

    /// Writes the current settings to Firestore (`users/{uid}.privacy` and the profile mirror).
    func push() async {
        guard me.uid != nil else { return }
        let snapshot = settings
        do {
            // The profile must exist before its visibility fields can be updated.
            _ = try await remote.ensureOwnProfile(displayName: displayName(), handleHint: nil, privacy: snapshot)
            try await remote.savePrivacy(snapshot)
            setPending(false)
            lastError = nil
        } catch {
            setPending(true)
            lastError = "Privacy changes are saved on this device and will sync when you're back online."
        }
    }

    /// Called on sign-in / launch. A change that never reached the server wins; otherwise the stored
    /// values replace the local ones (a new device), and a first-time user's defaults are published
    /// so their profile visibility matches.
    func restore() async {
        guard me.uid != nil else { return }
        if needsPush { await push(); return }
        do {
            if let stored = try await remote.loadPrivacy() {
                settings = stored
                stored.save(to: defaults)
                lastError = nil
            } else {
                await push()
            }
        } catch {
            lastError = nil   // offline: keep the local copy
        }
    }

    private func setPending(_ value: Bool) {
        needsPush = value
        defaults.set(value, forKey: Self.pendingKey)
    }
}
