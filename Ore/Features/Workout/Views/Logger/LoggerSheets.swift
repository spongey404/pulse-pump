import SwiftUI
import SwiftData

// MARK: - Rest sheet (tap the REST pill)

/// Big ring + time, −15S / +15S, the exercise's default rest (1:00 … 3:00) and SKIP REST.
struct RestSheet: View {
    let restTimer: RestTimerService
    /// The exercise whose default is being set.
    let exerciseId: UUID?
    let exerciseName: String
    let isCompound: Bool
    let templateSeconds: Int?
    var onClose: () -> Void
    @State private var defaultSeconds = 120
    private let options = [60, 90, 120, 150, 180]

    private var running: Bool { restTimer.isRunning }
    private var shownSeconds: Int { running ? restTimer.remainingSeconds : defaultSeconds }

    var body: some View {
        LoggerSheet(onClose: onClose) {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("REST").font(.archivo(20, weight: .black)).foregroundStyle(Color.inkPrimary)
                    Spacer()
                    LoggerLabel(text: running ? "COUNTING DOWN" : "NOT RUNNING")
                }
                HStack(spacing: 18) {
                    adjust("−15S") { if running { restTimer.adjust(by: -15) } }
                    ZStack {
                        Circle().stroke(Color.ruleStrong, lineWidth: 4)
                        Circle().trim(from: 0, to: running ? 1 - restTimer.progress : 0).stroke(Color.oreAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90)).animation(.linear(duration: 0.1), value: restTimer.progress)
                        Text(ExerciseCardView.clock(shownSeconds)).font(.spaceMono(34, weight: .bold)).foregroundStyle(Color.inkPrimary)
                            .accessibilityIdentifier(AX.workout.restModal)
                    }
                    .frame(width: 132, height: 132)
                    adjust("+15S") { if running { restTimer.adjust(by: 15) } else { restTimer.start(seconds: 15) } }
                }
                .padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 8) {
                    LoggerLabel(text: "DEFAULT · \(exerciseName.uppercased())")
                    HStack(spacing: 2) {
                        ForEach(options, id: \.self) { v in
                            Button { setDefault(v) } label: {
                                Text(ExerciseCardView.clock(v)).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                                    .foregroundStyle(defaultSeconds == v ? Color.inkPrimary : Color.inkMuted)
                                    .frame(maxWidth: .infinity).frame(height: 34)
                                    .background(defaultSeconds == v ? Color.surf : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3).background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                SheetButton(title: running ? "SKIP REST" : "CLOSE", glyph: "›", id: AX.workout.restSkip) { if running { restTimer.skip() }; onClose() }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            defaultSeconds = exerciseId.flatMap(RestTimerService.perExerciseOverride) ?? restTimer.restDuration(isCompound: isCompound, exerciseId: exerciseId, templateSeconds: templateSeconds)
        }
    }

    private func setDefault(_ v: Int) {
        defaultSeconds = v
        if let exerciseId { RestTimerService.setPerExerciseOverride(exerciseId: exerciseId, seconds: v) }
    }

    private func adjust(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(width: 64, height: 48)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
        }
        .buttonStyle(PressOpacityButtonStyle())
    }
}

// MARK: - Auto progression sheet

/// Toggle, "When you hit [− 8 +] reps", "Go up by +1.25 / +2.5 / +5 / +10", and what it does. Changes apply as you make them.
struct ProgressionSheet: View {
    let exerciseName: String
    @Binding var config: LoggerMath.ProgressionConfig
    var onClose: () -> Void
    @Environment(\.weightUnit) private var unit

    var body: some View {
        LoggerSheet(onClose: onClose) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        LoggerLabel(text: "AUTO PROGRESSION")
                        Text(exerciseName.uppercased()).font(.archivo(20, weight: .black)).foregroundStyle(Color.inkPrimary)
                    }
                    Spacer()
                    toggle
                }
                VStack(spacing: 0) {
                    row("When you hit", sub: "REPS ON A SET AT THAT WEIGHT") {
                        HStack(spacing: 6) {
                            box("−") { config.reps = max(1, config.reps - 1) }
                            Text("\(config.reps)").font(.spaceMono(22, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(minWidth: 48)
                            box("+") { config.reps += 1 }
                        }
                    }
                    row("Go up by", sub: "\(unit.label) ON THE NEXT SET") {
                        HStack(spacing: 2) {
                            ForEach(LoggerMath.ProgressionConfig.increments, id: \.self) { v in
                                let on = abs(config.incrementKg - v) < 0.001
                                Button { config.incrementKg = v } label: {
                                    Text("+\(LoggerMath.trim(unit.display(v)))").font(.spaceMono(12, weight: .bold))
                                        .foregroundStyle(on ? Color.inkPrimary : Color.inkMuted).frame(minWidth: 48).frame(height: 34).padding(.horizontal, 6)
                                        .background(on ? Color.surf : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3).background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                .opacity(config.enabled ? 1 : 0.4)
                Text("When a set reaches \(config.reps) reps, the next set is prefilled \(LoggerMath.trim(unit.display(config.incrementKg))) \(unit.label.lowercased()) heavier, in this workout or the next one. Prefills that went up show in blue.")
                    .font(.archivo(13)).foregroundStyle(Color.inkSecondary).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                SheetButton(title: "SAVE", glyph: "✓", filled: true, id: "workout.progression.save", action: onClose)
            }
            .padding(.horizontal, 16)
        }
    }

    private var toggle: some View {
        Button { withAnimation(.easeInOut(duration: 0.25)) { config.enabled.toggle() } } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(config.enabled ? Color.oreAccent : Color.surf2)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(config.enabled ? Color.clear : Color.ruleStrong, lineWidth: 1))
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white).frame(width: 24, height: 24).padding(3).offset(x: config.enabled ? 24 : 0)
            }
            .frame(width: 56, height: 32)
        }
        .buttonStyle(.plain).accessibilityLabel("Auto progression").accessibilityValue(config.enabled ? "On" : "Off").accessibilityIdentifier("workout.progression.toggle")
    }

    private func row<Trailing: View>(_ title: String, sub: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                LoggerLabel(text: sub)
            }
            Spacer()
            trailing()
        }
        .frame(minHeight: 60).overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func box(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(width: 40, height: 40)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
        }
        .buttonStyle(PressOpacityButtonStyle())
    }
}

// MARK: - Replace sheet

/// Search + same-muscle suggestions. Nothing logged → SWAP; some logged → SWITCH (logged sets stay, unlogged ones move to the new
/// exercise below). The original's family stays in the list so a swap can be undone.
struct ReplaceSheet: View {
    let entry: ExerciseEntry
    let currentExerciseIds: Set<UUID>
    var onPick: (Exercise) -> Void
    var onClose: () -> Void
    @Query(sort: \Exercise.name) private var library: [Exercise]
    @State private var query = ""
    @FocusState private var focused: Bool

    private var logged: Int { entry.sets.filter(\.isCompleted).count }
    private var unlogged: Int { entry.sets.count - logged }
    private var familyName: String { entry.familyName ?? entry.exerciseName }
    private var familyExercise: Exercise? { library.first { $0.name == familyName } ?? library.first { $0.id == entry.exerciseId } }
    private var muscles: [MuscleGroup] { familyExercise?.primaryMuscleGroups ?? [] }

    /// The family's own exercise first (swap back), then everything sharing a primary muscle.
    private var candidates: [Exercise] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let mine = Set(muscles)
        var list = library.filter { $0.id != entry.exerciseId && !$0.isCustomHidden && (mine.isEmpty || !mine.isDisjoint(with: $0.primaryMuscleGroups) || $0.name == familyName) }
        if !q.isEmpty { list = library.filter { $0.id != entry.exerciseId && $0.name.lowercased().contains(q) } }
        list.sort { a, b in (a.name == familyName ? 0 : 1, a.name) < (b.name == familyName ? 0 : 1, b.name) }
        return Array(list.prefix(40))
    }

    var body: some View {
        LoggerSheet(onClose: onClose) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    LoggerLabel(text: "REPLACE")
                    Text(entry.exerciseName.uppercased()).font(.archivo(20, weight: .black)).foregroundStyle(Color.inkPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                TextField("", text: $query, prompt: Text("Search exercises").foregroundStyle(Color.inkMuted)).font(.archivo(15)).foregroundStyle(Color.inkPrimary)
                    .focused($focused).padding(.horizontal, 12).frame(height: 44)
                    .background(Color.surf, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                    .padding(.horizontal, 16).accessibilityIdentifier("replace.search")
                LoggerLabel(text: "SAME MUSCLES · \(muscles.map { $0.displayName.uppercased() }.joined(separator: " · "))")
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(candidates, id: \.id) { ex in
                            Button { onPick(ex) } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ex.name).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                                        LoggerLabel(text: ex.equipmentType.displayName.uppercased() + ([EquipmentType.barbell, .ezBar, .trapBar].contains(ex.equipmentType) ? " · PLATES" : ""))
                                    }
                                    Spacer()
                                    Text(logged > 0 ? "SWITCH" : "SWAP").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                                }
                                .padding(.horizontal, 16).frame(minHeight: 52).contentShape(Rectangle())
                                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                            }
                            .buttonStyle(OreRowPressStyle()).accessibilityIdentifier("replace.row.\(AX.slug(ex.name))")
                        }
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                Text(message).font(.archivo(13)).foregroundStyle(Color.inkSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var message: String {
        logged == 0
            ? "Nothing is logged yet, so \(entry.exerciseName) is replaced. Your \(entry.sets.count) sets carry over."
            : "\(logged) logged set\(logged > 1 ? "s" : "") stay on \(entry.exerciseName). " + (unlogged > 0 ? "The other \(unlogged) move to the new exercise, added below it." : "The new exercise is added below it.")
    }
}

private extension Exercise {
    var isCustomHidden: Bool { deletedAt != nil }
}

// MARK: - Reorder list

/// REORDER: rows 56 pt with the grip, index, name and set count. Hold the grip and drag (the row lifts with an accent outline, the
/// others slide, drop to place), or use ▲ ▼.
struct ReorderList: View {
    let entries: [ExerciseEntry]
    var onMove: (Int, Int) -> Void
    @State private var dragFrom: Int?
    @State private var dy: CGFloat = 0
    private let rowHeight: CGFloat = 56

    private var target: Int? { dragFrom.map { max(0, min(entries.count - 1, $0 + Int((dy / rowHeight).rounded()))) } }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { i, e in row(i, e) }
        }
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.dsHairLine, lineWidth: 1))
    }

    private func shift(_ i: Int) -> CGFloat {
        guard let from = dragFrom, let to = target else { return 0 }
        if i == from { return dy }
        if from < to, i > from, i <= to { return -rowHeight }
        if from > to, i < from, i >= to { return rowHeight }
        return 0
    }

    private func row(_ i: Int, _ e: ExerciseEntry) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 1).fill(Color.inkMuted).frame(width: 18, height: 2) } }
                .frame(width: 40, height: 52).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2).onChanged { v in dragFrom = i; dy = v.translation.height }
                    .onEnded { _ in
                        if let from = dragFrom, let to = target, from != to { onMove(from, to) }
                        withAnimation(.easeOut(duration: 0.2)) { dragFrom = nil; dy = 0 }
                    })
            Text(String(format: "%02d", i + 1)).font(.spaceMono(10)).tracking(1.5).foregroundStyle(Color.inkMuted)
            VStack(alignment: .leading, spacing: 3) {
                Text(e.exerciseName.uppercased()).font(.archivo(15, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                LoggerLabel(text: "\(e.sets.filter(\.isCompleted).count)/\(e.sets.count) SETS" + (e.supersetGroup.map { " · SUPERSET \($0)" } ?? ""))
            }
            Spacer()
            arrow("▲", enabled: i > 0) { onMove(i, i - 1) }
            arrow("▼", enabled: i < entries.count - 1) { onMove(i, i + 1) }
        }
        .padding(.leading, 4).padding(.trailing, 8).frame(height: rowHeight)
        .background(Color.surf)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay { if dragFrom == i { RoundedRectangle(cornerRadius: 4).strokeBorder(Color.accentInk, lineWidth: 1) } }
        .offset(y: shift(i)).scaleEffect(dragFrom == i ? 1.02 : 1)
        .zIndex(dragFrom == i ? 5 : 0)
        .animation(dragFrom == i ? nil : .easeOut(duration: 0.2), value: dragFrom)
    }

    private func arrow(_ glyph: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(.spaceMono(11)).foregroundStyle(Color.inkPrimary).frame(width: 40, height: 40)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1)).opacity(enabled ? 1 : 0.3)
        }
        .buttonStyle(.plain).disabled(!enabled)
    }
}
