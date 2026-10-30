import Foundation

/// Where the social layer gets its backend. In Release this is always `FirestoreSocialRemote`.
/// In DEBUG a seeded in-memory remote can stand in, but only when `DevFlags.socialFixtures` is on,
/// which it never is while the emulator is in use (`-useFirebaseEmulator 1`).
enum SocialRemoteFactory {
    @MainActor
    static func make(user: CurrentUser) -> SocialRemote {
        #if DEBUG
        if DevFlags.socialFixtures {
            return SocialFixtures.makeRemote(meUid: user.uid ?? "dev-me")
        }
        #endif
        return FirestoreSocialRemote(user: user)
    }
}

/// Shared instances for the app's views. Tests build their own `SocialViewModel` / `PrivacyService`
/// with a `FakeSocialRemote` and never touch these.
@MainActor
enum SocialServices {
    static let currentUser: CurrentUser = {
        #if DEBUG
        // Fixtures need a signed-in identity even when nobody is signed in to Firebase.
        if DevFlags.socialFixtures { return SocialFixtures.currentUser }
        #endif
        return FirebaseCurrentUser()
    }()

    /// Set by the screens that have the SwiftData `User` at hand, so a new profile uses the name the
    /// person typed during onboarding rather than whatever Firebase Auth knows.
    static var localName: String?
    static var localHandle: String?

    static let remote: SocialRemote = SocialRemoteFactory.make(user: currentUser)

    static let privacy = PrivacyService(remote: remote, me: currentUser, displayName: {
        localName ?? currentUser.displayName ?? Brand.defaultUserName
    })

    static let viewModel = SocialViewModel(remote: remote, me: currentUser, privacy: privacy)
}
