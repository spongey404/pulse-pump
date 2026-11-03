import SwiftUI

/// "Search Apple Music": results with a ▶ that plays the 30 s preview; tapping a row attaches the song.
struct SongSearchSheet: View {
    var search: MusicSearching = ProcessInfo.processInfo.arguments.contains("-fakeMusicSearch") ? FakeMusicSearch() : AppleMusicSearch()
    let onPick: (PostSong) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PostSong] = []
    @State private var searching = false
    @FocusState private var focused: Bool
    private var player: PostSongPlayer { .shared }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.inkGhost).frame(width: 36, height: 4).padding(.top, 8).padding(.bottom, 12)
            HStack {
                Text("Search Apple Music").font(.archivo(22, weight: .black)).foregroundStyle(Color.inkPrimary)
                Spacer()
                Button("Cancel") { player.pauseAll(); dismiss() }.font(.archivo(14, weight: .semibold)).foregroundStyle(Color.accentInk)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
            TextField("", text: $query, prompt: Text("Song or artist").foregroundStyle(Color.inkMuted))
                .font(.archivo(15)).foregroundStyle(Color.inkPrimary)
                .focused($focused).submitLabel(.search)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 16)
                .accessibilityIdentifier("song.search")
            ScrollView {
                VStack(spacing: 0) {
                    if results.isEmpty && !query.isEmpty && !searching {
                        Text("No songs found.").font(.archivo(13)).foregroundStyle(Color.inkMuted).padding(.top, 24)
                    }
                    ForEach(results, id: \.listId) { song in row(song) }
                }
                .padding(.top, 8)
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear { focused = true }
        .task(id: query) {
            searching = true
            try? await Task.sleep(for: .milliseconds(250))      // debounce typing
            guard !Task.isCancelled else { return }
            results = await search.search(query)
            searching = false
        }
        .onDisappear { player.pauseAll() }
    }

    private func row(_ song: PostSong) -> some View {
        let id = "search:\(song.appleMusicId ?? song.title)"
        return HStack(spacing: 10) {
            Group {
                if let a = song.artworkURL { AsyncImage(url: URL(string: a)) { $0.image?.resizable().scaledToFill() } } else { Color.surf2 }
            }
            .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                Text(song.artist.uppercased()).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { player.toggle(postId: id, song: song) } label: {
                SongPlayKey(playing: player.isPlaying(id), accent: Color.oreAccent)
            }
            .buttonStyle(.plain).accessibilityLabel("Preview \(song.title)")
        }
        .padding(.horizontal, 16).frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture { player.pauseAll(); onPick(song); dismiss() }
        .accessibilityIdentifier("song.row.\(song.title)")
    }
}

private extension PostSong { var listId: String { appleMusicId ?? "\(title)-\(artist)" } }
