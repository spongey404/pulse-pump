import SwiftUI
import PhotosUI

/// The composer (Ore Feed Post Final §3c): fits one screen. Header, a preview card (photo tile + body map tile, stats), the caption,
/// a song, who it was trained with, who can see it, then the docked POST and ···. No ticker here: that lives on the exported card.
struct PostComposerPage: View {
    let data: WorkoutCompletionData
    @Bindable var model: PostComposerModel
    var levels: [String: Double]
    var namespace: Namespace.ID
    var onPost: () -> Void
    var onShare: () -> Void
    var onSaveDraft: () -> Void
    var onDontPost: () -> Void
    var onBack: () -> Void

    @Environment(\.weightUnit) private var unit
    @State private var picker: PhotosPickerItem?
    @State private var songSheet = false
    @State private var menuOpen = false
    @State private var friends: [FirestoreUserProfile] = []
    private let tileHeight: CGFloat = 150

    private var member: Bool { AccentStore.shared.stardustEnabled }
    private var dateLine: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return "WORKOUT COMPLETE · \(f.string(from: Date()).uppercased())"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    previewCard
                    caption
                    songSection
                    trainedWith
                    whoCanSee
                }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { dock }
        .sheet(isPresented: $songSheet) { SongSearchSheet { model.song = $0 } }
        .onChange(of: picker) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { model.setPhoto(img) }
                picker = nil
            }
        }
        .task { await SocialViewModel.shared.loadGraph(); friends = SocialViewModel.shared.friends }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLine).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    .accessibilityIdentifier(AX.completion.title)
                Text((data.workoutName ?? "WORKOUT").uppercased()).font(.archivo(26, weight: .black)).tracking(0.5)
                    .foregroundStyle(Color.inkPrimary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: onBack) {
                Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary).frame(width: 44, height: 44)
                    .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain).accessibilityLabel("Back to summary").accessibilityIdentifier(AX.completion.back)
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: Preview card (both tiles 150 pt, stats under)

    private var previewCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                photoTile
                mapTile
            }
            .padding(10)
            HStack(spacing: 8) {
                stat("SETS", "\(data.totalSets)")
                stat("VOLUME", unit.compactVolume(volumeKg))
                stat("TIME", PostTime.duration(Int(data.duration)))
            }
            .padding(.horizontal, 14).padding(.bottom, 12)
        }
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var volumeKg: Double { data.exercises.flatMap(\.workingSets).reduce(0) { $0 + $1.weight * Double($1.reps) } }

    private func stat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            Text(v).font(.spaceMono(17, weight: .bold)).foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoTile: some View {
        ZStack {
            if let img = model.photo {
                Image(uiImage: img).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: tileHeight).clipped()
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 6) {
                            PhotosPicker(selection: $picker, matching: .images) { chip("REPLACE") }
                            Button { model.removePhoto() } label: { chip("REMOVE") }.buttonStyle(.plain)
                        }.padding(6)
                    }
            } else {
                PhotosPicker(selection: $picker, matching: .images) {
                    VStack(spacing: 6) {
                        Text("+").font(.archivo(22)).foregroundStyle(Color.inkMuted)
                        Text("ADD PHOTO").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                        Text("OPTIONAL · SHOWS FIRST").font(.spaceMono(7)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                }
                .accessibilityIdentifier("composer.addPhoto")
            }
        }
        .frame(maxWidth: .infinity).frame(height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func chip(_ t: String) -> some View {
        Text(t).font(.spaceMono(7, weight: .bold)).tracking(1.2).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 5).background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
    }

    private var mapTile: some View {
        ZStack {
            Color.surf2
            BodyMapSwapView(levels: levels, member: member, accentHex: member ? AccentStore.shared.active.hexString : nil,
                            tileSize: CGSize(width: 44, height: 64), figureInset: 6)
        }
        .frame(maxWidth: .infinity).frame(height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .matchedGeometryEffect(id: "map", in: namespace)
        .accessibilityIdentifier("composer.mapTile")
    }

    // MARK: Caption, song, tags, audience

    private var caption: some View {
        TextField("", text: $model.caption, prompt: Text("Say something about it").foregroundStyle(Color.inkMuted), axis: .vertical)
            .font(.archivo(15)).foregroundStyle(Color.inkPrimary).lineLimit(1...3)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .accessibilityIdentifier(AX.completion.caption)
    }

    @ViewBuilder private var songSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ComposerLabel(text: "SONG")
            if let song = model.song {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.title).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        Text(song.artist.uppercased()).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
                    }
                    Spacer()
                    Button("CHANGE") { songSheet = true }.font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                    Button("REMOVE") { model.song = nil }.font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 12).frame(height: 40)
                .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Button { songSheet = true } label: {
                    Text("+ ADD A SONG").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                }
                .buttonStyle(.plain).accessibilityIdentifier("composer.addSong")
            }
        }
    }

    private var trainedWith: some View {
        VStack(alignment: .leading, spacing: 6) {
            ComposerLabel(text: "TRAINED WITH")
            if !model.tagged.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(model.tagged, id: \.uid) { f in TaggedChip(name: f.shownName) { model.untag(f) } }
                }
            }
            TextField("", text: $model.friendQuery, prompt: Text("Search friends").foregroundStyle(Color.inkMuted))
                .font(.archivo(14)).foregroundStyle(Color.inkPrimary).autocorrectionDisabled()
                .padding(.horizontal, 12).frame(height: 40)
                .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("composer.friendSearch")
            if let found = PostComposerModel.matches(friends, query: model.friendQuery, excluding: model.tagged) {
                if found.isEmpty {
                    Text("No friends match.").font(.archivo(13)).foregroundStyle(Color.inkMuted).padding(.vertical, 6)
                } else {
                    ForEach(found.prefix(4), id: \.uid) { f in
                        Button { model.tag(f) } label: {
                            Text(f.shownName).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("composer.friend.\(f.shownName)")
                    }
                }
            }
        }
    }

    private var whoCanSee: some View {
        HStack {
            ComposerLabel(text: "WHO CAN SEE IT")
            Spacer()
            SegmentedChoice(options: [("FRIENDS", false), ("ONLY ME", true)], selection: $model.onlyMe)
        }
    }

    // MARK: Dock

    private var dock: some View {
        HStack(spacing: 10) {
            DockedPrimaryButton(title: "POST", id: AX.completion.cta, action: onPost)
            Button { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil); menuOpen = true } label: {
                Text("···").font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkMuted).frame(width: 60, height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
            }
            .buttonStyle(.plain).accessibilityLabel("More").accessibilityIdentifier(AX.completion.menu)
            .popover(isPresented: $menuOpen, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                PostMenuPopover {
                    PostMenuRow(title: "Share outside Ore") { menuOpen = false; onShare() }
                    PostMenuRow(title: "Save as draft", detail: "Post it later from History") { menuOpen = false; onSaveDraft() }
                    PostMenuRow(title: "Don't post", detail: "The workout stays in your History", destructive: true, id: AX.completion.dontPost) { menuOpen = false; onDontPost() }
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
        .background(Color.canvasBg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
