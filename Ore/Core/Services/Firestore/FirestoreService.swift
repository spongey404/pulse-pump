import Foundation

/// Compatibility shim only. The old `FirestoreService` (feed / friendships / challenge arrays in
/// documents) is gone; the social layer is `SocialRemote` (`FirestoreSocialRemote`) behind
/// `SocialViewModel`. The one call kept here is the onboarding sign-in hook, which now just makes
/// sure `profiles/{uid}` exists (claiming a handle) without ever overwriting an existing profile.
///
/// Auth/onboarding code should call `SocialServices.viewModel.loadMyProfile()` instead; delete this
/// type once nothing references it.
@MainActor
final class FirestoreService {
    @available(*, deprecated, message: "Use SocialServices.viewModel.loadMyProfile()")
    func createOrUpdateUserProfile(_ profile: FirestoreUserProfile) async throws {
        _ = try await SocialServices.remote.ensureOwnProfile(
            displayName: profile.displayName,
            handleHint: profile.username,
            privacy: SocialServices.privacy.settings)
    }
}
