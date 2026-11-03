import Foundation

/// "Save as draft" from the composer: the finished post payload (and its photo) kept on this device until the person posts it from
/// History ("Post it later from History"). Keyed by the workout's id, which is also the post id.
final class PostDraftStore: @unchecked Sendable {
    static let shared = PostDraftStore()

    struct Draft: Codable, Equatable {
        var payload: PostPayload
        var photoFile: String?
        var savedAt: Date
    }

    private let defaults: UserDefaults
    private let folder: URL
    private let key = "social.postDrafts"

    init(defaults: UserDefaults = .standard, folder: URL? = nil) {
        self.defaults = defaults
        self.folder = folder ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("PostDrafts", isDirectory: true)
    }

    private func all() -> [String: Draft] {
        guard let data = defaults.data(forKey: key), let d = try? JSONDecoder().decode([String: Draft].self, from: data) else { return [:] }
        return d
    }

    private func write(_ d: [String: Draft]) { defaults.set(try? JSONEncoder().encode(d), forKey: key) }

    func save(_ payload: PostPayload, photoJPEG: Data?, now: Date = Date()) {
        var file: String?
        if let photoJPEG {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            file = "\(payload.postId).jpg"
            try? photoJPEG.write(to: folder.appendingPathComponent(file!))
        }
        var d = all()
        d[payload.postId] = Draft(payload: payload, photoFile: file, savedAt: now)
        write(d)
    }

    func draft(forWorkout id: String) -> Draft? { all()[id.lowercased()] }
    func hasDraft(forWorkout id: String) -> Bool { draft(forWorkout: id) != nil }

    func photo(of draft: Draft) -> Data? { draft.photoFile.flatMap { try? Data(contentsOf: folder.appendingPathComponent($0)) } }

    func discard(workout id: String) {
        var d = all()
        if let f = d[id.lowercased()]?.photoFile { try? FileManager.default.removeItem(at: folder.appendingPathComponent(f)) }
        d[id.lowercased()] = nil
        write(d)
    }
}
