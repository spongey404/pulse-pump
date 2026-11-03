import SwiftUI
import PhotosUI

/// The composer's state (Ore Feed Post Final §3c). Pure rules live here so they can be tested; the view only draws.
@Observable
final class PostComposerModel {
    var caption = ""
    var photoJPEG: Data?
    var photo: UIImage?
    var song: PostSong?
    var tagged: [FirestoreUserProfile] = []
    var friendQuery = ""
    /// WHO CAN SEE IT: false = FRIENDS, true = ONLY ME.
    var onlyMe = false

    /// No list until the person types; tapping a result tags them and clears the field; already-tagged friends are not offered again.
    static func matches(_ friends: [FirestoreUserProfile], query: String, excluding tagged: [FirestoreUserProfile]) -> [FirestoreUserProfile]? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return nil }
        let taken = Set(tagged.map(\.uid))
        return friends.filter { !taken.contains($0.uid) && ($0.shownName.lowercased().contains(q) || $0.username.lowercased().contains(q)) }
    }

    func tag(_ f: FirestoreUserProfile) {
        guard !tagged.contains(where: { $0.uid == f.uid }), tagged.count < 20 else { return }
        tagged.append(f)
        friendQuery = ""
    }

    func untag(_ f: FirestoreUserProfile) { tagged.removeAll { $0.uid == f.uid } }

    func setPhoto(_ image: UIImage) {
        photo = image
        photoJPEG = Self.jpeg(image)
    }

    func removePhoto() { photo = nil; photoJPEG = nil }

    /// Long edge 1600 pt at 0.8 quality keeps the upload well under the 8 MB storage rule.
    static func jpeg(_ image: UIImage, maxEdge: CGFloat = 1600) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let r = UIGraphicsImageRenderer(size: size)
        return r.jpegData(withCompressionQuality: 0.8) { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    var extras: PostExtras {
        PostExtras(photoURL: nil, song: song, taggedNames: tagged.map(\.shownName), onlyMe: onlyMe)
    }
}
