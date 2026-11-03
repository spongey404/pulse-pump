import SwiftUI
import SwiftData

/// Add exercises (Ore Programs 07–09): a full-screen page, not a sheet. Search (types too), a movement row (selected = solid accent) and a
/// muscle row (selected = accent tint, outline and text), rows with an outlined + ADD that becomes a solid ADDED (no tick circles: those are for
/// logging sets), "N TYPES ›" rows open CHOOSE A TYPE, and one docked ADD N EXERCISES. New exercises start at 3 × 8–12, RIR 2, rest 1:30.
struct ProgramAddExercisesView: View {
    let template: WorkoutTemplate
    let onBack: () -> Void
    let onDone: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name) private var exercises: [Exercise]
    @State private var query = ""
    @State private var move: ProgramPicker.Move = .all
    @State private var muscle: ProgramPicker.Muscle = .all
    @State private var picked: [UUID] = []
    @State private var group: ProgramPicker.Item?

    private var present: Set<UUID> { Set(template.templateExercises.map(\.exerciseId)) }
    private var items: [ProgramPicker.Item] { ProgramPicker.items(exercises: exercises, query: query, move: move, muscle: muscle, excluded: present) }

    var body: some View {
        VStack(spacing: 0) {
            ProgramPageHeader(kicker: group == nil ? "ADD TO \(template.name.uppercased())" : "ADD TO \(template.name.uppercased())",
                              title: group == nil ? "ADD EXERCISES" : "CHOOSE A TYPE", titleSize: 22, onBack: { if group != nil { group = nil } else { onBack() } })
            if group == nil { filters }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let group { ForEach(group.exercises, id: \.id) { leaf($0, title: $0.name) } }
                    else { ForEach(items) { item in item.isGroup ? AnyView(groupRow(item)) : AnyView(leaf(item.exercises[0], title: item.title)) } }
                    if group == nil && items.isEmpty {
                        Text("No exercises match.").font(.archivo(14)).foregroundStyle(Color.inkMuted).padding(.top, 32)
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProgramDock {
                ProgramDockedButton(title: ProgramPicker.dockTitle(count: picked.count), enabled: !picked.isEmpty, id: AX.programs.pickDock, height: 56) { addPicked() }
            }
        }
    }

    // MARK: Filters

    private var filters: some View {
        VStack(spacing: 10) {
            TextField("", text: $query, prompt: Text("Search exercises").foregroundStyle(Color.inkMuted)).font(.archivo(15)).foregroundStyle(Color.inkPrimary)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.surf, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                .padding(.horizontal, 16).accessibilityIdentifier(AX.programs.pickSearch)
            chips(ProgramPicker.Move.allCases, selected: move, solid: true, id: { AX.programs.pickMove($0.rawValue) }) { move = $0 }
            chips(ProgramPicker.Muscle.allCases, selected: muscle, solid: false, id: { AX.programs.pickMuscle($0.rawValue) }) { muscle = $0 }
        }
        .padding(.top, 10).padding(.bottom, 10)
    }

    /// 999 pt filter chips (multi-select filters keep the pill; these are single filters of a list). Movement: the selected one is solid accent.
    /// Muscle: the selected one is an accent tint with an accent outline and accent text, not black.
    private func chips<T: Hashable & RawRepresentable>(_ all: [T], selected: T, solid: Bool, id: @escaping (T) -> String, _ pick: @escaping (T) -> Void) -> some View where T.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(all, id: \.self) { c in
                    let on = c == selected
                    Button { pick(c) } label: {
                        Text(c.rawValue).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                            .foregroundStyle(on ? (solid ? Color.white : Color.accentInk) : Color.inkSecondary)
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(on ? (solid ? Color.oreAccent : Color.accentSoft) : Color.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? (solid ? Color.oreAccent : Color.accentInk) : Color.ruleStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier(id(c)).accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Rows

    private func groupRow(_ item: ProgramPicker.Item) -> some View {
        let n = item.exercises.filter { picked.contains($0.id) }.count
        return Button { group = item } label: {
            HStack(spacing: 12) {
                nameBlock(item.title, item.muscles)
                Text(ProgramPicker.typesLabel(typeCount: item.exercises.count, picked: n) + " ›").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 6).frame(minHeight: 56).contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .buttonStyle(OreRowPressStyle()).accessibilityIdentifier(AX.programs.pickRow(item.title))
    }

    private func leaf(_ e: Exercise, title: String) -> some View {
        let on = picked.contains(e.id)
        return HStack(spacing: 12) {
            nameBlock(title, e.primaryMuscleGroups.map { $0.displayName.uppercased() }.joined(separator: " · "))
            Button { toggle(e.id) } label: {
                Text(on ? "ADDED" : "+ ADD").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(on ? Color.white : Color.inkPrimary)
                    .frame(minWidth: 72).padding(.horizontal, 10).frame(height: 32)
                    .background(on ? Color.oreAccent : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(on ? Color.oreAccent : Color.ruleStrong, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.programs.pickAdd(title)).accessibilityValue(on ? "Added" : "")
        }
        .padding(.horizontal, 16).padding(.vertical, 6).frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AX.programs.pickRow(title))
    }

    private func nameBlock(_ title: String, _ meta: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.archivo(15, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
            if !meta.isEmpty { Text(meta).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ id: UUID) { if let i = picked.firstIndex(of: id) { picked.remove(at: i) } else { picked.append(id) } }

    private func addPicked() {
        var items = template.templateExercises.sorted { $0.order < $1.order }
        for id in picked {
            guard let e = exercises.first(where: { $0.id == id }) else { continue }
            items.append(ProgramPlan.defaultExercise(id: e.id, name: e.name, order: items.count))
        }
        template.templateExercises = items
        template.markUpdated()
        try? modelContext.save()
        onDone()
    }
}
