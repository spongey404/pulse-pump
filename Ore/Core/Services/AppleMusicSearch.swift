import Foundation
import MusicKit

/// Apple Music search for the composer's song sheet: catalogue songs with their 30 s preview. Spotify is link-out only (never played here).
protocol MusicSearching: Sendable {
    func search(_ term: String) async -> [PostSong]
}

struct AppleMusicSearch: MusicSearching {
    func search(_ term: String) async -> [PostSong] {
        let q = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        if MusicAuthorization.currentStatus == .notDetermined { _ = await MusicAuthorization.request() }
        guard MusicAuthorization.currentStatus == .authorized else { return [] }
        var request = MusicCatalogSearchRequest(term: q, types: [Song.self])
        request.limit = 15
        guard let response = try? await request.response() else { return [] }
        return response.songs.map { s in
            PostSong(title: s.title, artist: s.artistName, artworkURL: s.artwork?.url(width: 120, height: 120)?.absoluteString,
                     previewURL: s.previewAssets?.first?.url?.absoluteString, appleMusicId: s.id.rawValue)
        }
    }
}

/// Deterministic results for UI tests and previews (no network, no authorisation prompt).
struct FakeMusicSearch: MusicSearching {
    var songs: [PostSong] = [PostSong(title: "Eye of the Tiger", artist: "Survivor"), PostSong(title: "Stronger", artist: "Kanye West"),
                             PostSong(title: "Lose Yourself", artist: "Eminem")]
    func search(_ term: String) async -> [PostSong] {
        let t = term.lowercased()
        return t.count < 2 ? [] : songs.filter { $0.title.lowercased().contains(t) || $0.artist.lowercased().contains(t) }
    }
}
