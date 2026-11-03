import Foundation
import AVFoundation

/// A song attached to a post: Apple Music search result with its 30 s preview (Spotify is link-out only, never played here).
struct PostSong: Codable, Equatable {
    var title: String
    var artist: String
    var artworkURL: String?
    var previewURL: String?
    /// Apple Music catalogue id (for the link-out and for re-resolving an expired preview URL).
    var appleMusicId: String?
}

/// Pure playback state for one post's preview. Position is whole seconds shown as "0:12 / 0:30".
struct SongPlaybackState: Equatable {
    var position: Double = 0
    var playing = false
    /// Resets to the "PREVIEW 0:30" label at the end.
    var label: String { Self.label(position: position, playing: playing, length: SocialConfigStore.shared.current.song.previewSeconds) }

    static func clock(_ s: Double) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }
    static func label(position: Double, playing: Bool, length: Double) -> String {
        (position <= 0 && !playing) ? "PREVIEW \(clock(length))" : "\(clock(position)) / \(clock(length))"
    }

    mutating func tick(by dt: Double, length: Double) {
        guard playing else { return }
        position += dt
        if position >= length { position = 0; playing = false }
    }
}

/// One shared player for the feed so starting another post's song pauses this one and remembers its spot. Nothing autoplays.
/// Audio comes from the preview URL through AVPlayer; with no URL (tests, previews) the clock still runs so the UI is exercised.
@Observable
final class PostSongPlayer {
    static let shared = PostSongPlayer()

    private(set) var states: [String: SongPlaybackState] = [:]
    private(set) var currentPostId: String?
    private var player: AVPlayer?
    private var timer: Timer?
    private var urls: [String: URL] = [:]
    private var last = Date()
    /// Set by tests so no audio session or network is touched.
    var silent = false

    func state(_ postId: String) -> SongPlaybackState { states[postId] ?? SongPlaybackState() }
    func isPlaying(_ postId: String) -> Bool { state(postId).playing }

    func toggle(postId: String, song: PostSong) {
        if isPlaying(postId) { pause(postId) } else { play(postId: postId, song: song) }
    }

    func play(postId: String, song: PostSong) {
        if let current = currentPostId, current != postId { pause(current) }
        currentPostId = postId
        var s = state(postId)
        s.playing = true
        states[postId] = s
        if let str = song.previewURL, let url = URL(string: str) { urls[postId] = url }
        startAudio(postId)
        last = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.advance() }
    }

    func pause(_ postId: String) {
        var s = state(postId)
        s.playing = false
        states[postId] = s          // position is kept: play resumes from that second
        if currentPostId == postId { player?.pause(); timer?.invalidate(); timer = nil }
    }

    func pauseAll() { if let id = currentPostId { pause(id) } }

    private func advance() {
        guard let id = currentPostId else { return }
        let now = Date(); let dt = now.timeIntervalSince(last); last = now
        var s = state(id)
        s.tick(by: dt, length: SocialConfigStore.shared.current.song.previewSeconds)
        states[id] = s
        if !s.playing { player?.pause(); player?.seek(to: .zero); timer?.invalidate(); timer = nil }
    }

    private func startAudio(_ postId: String) {
        guard !silent, let url = urls[postId] else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        p.seek(to: CMTime(seconds: state(postId).position, preferredTimescale: 600))
        p.play()
        player = p
    }
}
