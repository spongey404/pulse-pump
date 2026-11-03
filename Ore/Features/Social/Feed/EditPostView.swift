import SwiftUI
import SwiftData
import PhotosUI

/// Edit post (Ore Feed Post Final §2): PHOTO, SONG, CAPTION, TRAINED WITH, WORKOUT (each exercise a card, expandable to its sets), docked SAVE.
/// Only the author reaches this screen; the rules enforce it again on the server.
struct EditPostView: View {
    let post: WorkoutFeedItem
    var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var unit
    @State private var model: EditPostModel
    @State private var open: Set<String> = []
    @State private var picker: PhotosPickerItem?
    @State private var newPhoto: UIImage?
    @State private var songSheet = false
    @State private var addExercise = false
    @State private var query = ""
    @State private var friends: [FirestoreUserProfile] = []
    @State private var saving = false
    @Query(sort: \Exercise.name) private var library: [Exercise]

    init(post: WorkoutFeedItem, viewModel: SocialViewModel) {
        self.post = post
        self.viewModel = viewModel
        _model = State(initialValue: EditPostModel(post: post))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    photoSection
                    songSection
                    captionSection
                    trainedWith
                    workoutSection
                    Text("Changes also update your History, the stats and the body map. The post shows EDITED.")
                        .font(.archivo(13)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DockedPrimaryButton(title: saving ? "SAVING" : "SAVE", disabled: saving || !model.isValid, id: "edit.save", action: save)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
                .background(Color.canvasBg.ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .sheet(isPresented: $songSheet) { SongSearchSheet { model.song = $0 } }
        .sheet(isPresented: $addExercise) { exercisePicker }
        .onChange(of: picker) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    newPhoto = img; model.newPhotoJPEG = PostComposerModel.jpeg(img); model.removePhoto = false
                }
                picker = nil
            }
        }
        .task { await viewModel.loadGraph(); friends = viewModel.friends }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary).frame(width: 44, height: 44)
                    .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain).accessibilityLabel("Back").accessibilityIdentifier(AX.nav.back)
            Text("EDIT POST").font(.archivo(24, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: Photo, song, caption, tags

    private var hasPhoto: Bool { (newPhoto != nil) || (model.photoURL != nil && !model.removePhoto) }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ComposerLabel(text: "PHOTO")
            if hasPhoto {
                HStack(spacing: 12) {
                    Group {
                        if let newPhoto { Image(uiImage: newPhoto).resizable().scaledToFill() }
                        else { AsyncImage(url: URL(string: model.photoURL ?? "")) { $0.image?.resizable().scaledToFill() } }
                    }
                    .frame(width: 72, height: 72).background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    PhotosPicker(selection: $picker, matching: .images) { smallAction("REPLACE") }
                    Button { newPhoto = nil; model.newPhotoJPEG = nil; model.removePhoto = true } label: { smallAction("REMOVE") }.buttonStyle(.plain)
                    Spacer()
                }
            } else {
                PhotosPicker(selection: $picker, matching: .images) { dashed("+ ADD PHOTO") }
            }
        }
    }

    private var songSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ComposerLabel(text: "SONG")
            if let s = model.song {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.title).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        Text(s.artist.uppercased()).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
                    }
                    Spacer()
                    Button { songSheet = true } label: { smallAction("CHANGE") }.buttonStyle(.plain)
                    Button { model.song = nil } label: { smallAction("REMOVE") }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).frame(height: 52).background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Button { songSheet = true } label: { dashed("+ ADD A SONG") }.buttonStyle(.plain)
            }
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ComposerLabel(text: "CAPTION")
            TextField("", text: $model.caption, prompt: Text("Say something about it").foregroundStyle(Color.inkMuted), axis: .vertical)
                .font(.archivo(15)).foregroundStyle(Color.inkPrimary).lineLimit(1...4).padding(12)
                .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("edit.caption")
        }
    }

    private var trainedWith: some View {
        VStack(alignment: .leading, spacing: 8) {
            ComposerLabel(text: "TRAINED WITH")
            if !model.taggedUids.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(zip(model.taggedUids, model.taggedNames).enumerated()), id: \.offset) { _, pair in
                        TaggedChip(name: pair.1) { model.untag(uid: pair.0) }
                    }
                }
            }
            TextField("", text: $query, prompt: Text("Search friends").foregroundStyle(Color.inkMuted))
                .font(.archivo(14)).foregroundStyle(Color.inkPrimary).autocorrectionDisabled()
                .padding(.horizontal, 12).frame(height: 40).background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            let taken = Set(model.taggedUids)
            if let found = PostComposerModel.matches(friends, query: query, excluding: friends.filter { taken.contains($0.uid) }) {
                if found.isEmpty { Text("No friends match.").font(.archivo(13)).foregroundStyle(Color.inkMuted) }
                ForEach(found.prefix(4), id: \.uid) { f in
                    Button { model.tag(uid: f.uid, name: f.shownName); query = "" } label: {
                        Text(f.shownName).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Workout (cards)

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ComposerLabel(text: "WORKOUT")
                Spacer()
                Text("\(model.workingSetCount) SETS · \(unit.compactVolume(model.volumeKg))").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
            }
            ForEach(Array(model.exercises.enumerated()), id: \.element.id) { i, e in card(i, e) }
            Button { addExercise = true } label: { dashed("+ ADD EXERCISE") }.buttonStyle(.plain).accessibilityIdentifier("edit.addExercise")
        }
    }

    private func card(_ i: Int, _ e: EditPostModel.EditableExercise) -> some View {
        let isOpen = open.contains(e.id)
        let sum = model.summary(of: e)
        return VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { if isOpen { open.remove(e.id) } else { open.insert(e.id) } } } label: {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", i + 1)).font(.spaceMono(10)).foregroundStyle(Color.inkMuted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.name.uppercased()).font(.archivo(17, weight: .black)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        Text("\(sum.sets) SETS" + (sum.topKg > 0 ? " · TOP \(unit.number(sum.topKg)) \(unit.label)" : "")).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                    Text("›").font(.spaceMono(18)).foregroundStyle(Color.inkMuted).rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(14).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                HStack(spacing: 8) {
                    Text("#").frame(width: 28, alignment: .leading)
                    Text(unit.label).frame(maxWidth: .infinity, alignment: .leading)
                    Text("REPS").frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 28)
                }
                .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.horizontal, 14).padding(.vertical, 9).background(Color.surf2)
                ForEach(Array(e.sets.enumerated()), id: \.element.id) { si, s in setRow(e, si, s) }
                Button { model.addSet(to: e.id) } label: { dashed("+ ADD SET", height: 36) }.buttonStyle(.plain).padding(12)
            }
        }
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func setRow(_ e: EditPostModel.EditableExercise, _ si: Int, _ s: EditPostModel.EditableSet) -> some View {
        let ei = model.exercises.firstIndex { $0.id == e.id }!
        return HStack(spacing: 8) {
            Text(String(format: "%02d", si + 1)).font(.spaceMono(12)).foregroundStyle(Color.inkMuted).frame(width: 28, alignment: .leading)
            KgTextField(kgString: Binding(get: { String(format: "%g", model.exercises[ei].sets[si].weightKg) },
                                          set: { model.exercises[ei].sets[si].weightKg = Double($0) ?? 0 }), unit: unit, placeholder: "0")
                .keyboardType(.decimalPad).font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("0", value: Binding(get: { model.exercises[ei].sets[si].reps }, set: { model.exercises[ei].sets[si].reps = max(0, $0) }), format: .number)
                .keyboardType(.numberPad).font(.spaceMono(14, weight: .bold)).foregroundStyle(s.isNew ? Color.accentInk : Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { model.removeSet(s.id, from: e.id) } label: { Text("×").font(.archivo(18)).foregroundStyle(Color.inkMuted).frame(width: 28, height: 40) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).frame(height: 40)
        .overlay(alignment: .leading) { if s.isNew { Rectangle().fill(Color.oreAccent).frame(width: 2) } }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var exercisePicker: some View {
        NavigationStack {
            List(library.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }.prefix(60), id: \.id) { ex in
                Button { model.addExercise(named: ex.name); addExercise = false } label: {
                    Text(ex.name.exerciseTitleCase).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary).frame(minHeight: 40)
                }
            }
            .searchable(text: $query)
            .navigationTitle("Add exercise").navigationBarTitleDisplayMode(.inline)
        }
    }

    private func smallAction(_ t: String) -> some View {
        Text(t).font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk).padding(.horizontal, 10).frame(height: 32)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
    }

    private func dashed(_ t: String, height: CGFloat = 40) -> some View {
        Text(t).font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted).frame(maxWidth: .infinity).frame(height: height)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }

    // MARK: Save

    private func save() {
        saving = true
        let wid = UUID(uuidString: post.id)
        var recalc = model.recalculate { name in
            guard let wid else { return .init(sets: []) }
            return EditPostModel.localHistory(context: modelContext, workoutId: wid, name: name)
        }
        recalc.exercises = EditPostModel.withMuscles(recalc.exercises, context: modelContext)
        Task {
            if let wid { model.applyToHistory(context: modelContext, workoutId: wid) }
            let ok = await viewModel.updatePost(post, edit: model, recalc: recalc)
            saving = false
            if ok { dismiss() }
        }
    }
}
