import Foundation
import FirebaseStorage

/// Post photos in Firebase Storage at `posts/{authorUid}/{postId}/photo.jpg`. Only the author can write or delete (`storage.rules`).
final class PostPhotoStore: @unchecked Sendable {
    static let shared = PostPhotoStore()

    static func path(authorUid: String, postId: String) -> String { "posts/\(authorUid)/\(postId)/photo.jpg" }

    func upload(jpeg: Data, authorUid: String, postId: String) async throws -> String {
        let ref = Storage.storage().reference(withPath: Self.path(authorUid: authorUid, postId: postId))
        let meta = StorageMetadata(); meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(jpeg, metadata: meta)
        return try await ref.downloadURL().absoluteString
    }

    func delete(authorUid: String, postId: String) async {
        try? await Storage.storage().reference(withPath: Self.path(authorUid: authorUid, postId: postId)).delete()
    }
}
