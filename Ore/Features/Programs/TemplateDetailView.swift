import SwiftUI
import SwiftData

private struct RestTimerTarget: Identifiable {
    let id: UUID
    let name: String
}

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let groupName: String?
    let siblings: [WorkoutTemplate]
    let onStartWorkout: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showExercisePicker = false
    @State private var expandedExercises: Set<UUID> = []
    @State private var activeTemplateId: UUID
    @State private var isEditing = false
    @State private var setTypesMap: [UUID: [String]] = [:]
    @State private var typePickerKey: String? = nil
    @State private var restTimerTarget: RestTimerTarget? = nil
    @State private var pendingRestSeconds: Int = 90
    @State private var restPickerMinutes: Int = 1
    @State private var restPickerSeconds: Int = 30

    private static let setTypeOptions: [(id: String, label: String)] =
        SetType.allCases.map { ($0.shortName, $0.displayName) }

    private func setType(for ex: TemplateExercise, at i: Int) -> String {
        if let types = setTypesMap[ex.id], i < types.count { return types[i] }
        return i == 0 && ex.targetSets > 1 ? "WU" : "STD"
    }

    private func updateSetType(exerciseId: UUID, at i: Int, newType: String, totalSets: Int) {
        var types = setTypesMap[exerciseId] ?? (0..<totalSets).map { $0 == 0 && totalSets > 1 ? "WU" : "STD" }
        while types.count <= i { types.append("STD") }
        types[i] = newType
        setTypesMap[exerciseId] = types
    }

    private func chipStyle(for type: String) -> (bg: Color, fg: Color) {
        switch type {
        case "WU":   return (Color(hex: "#a17418").opacity(0.18), Color(hex: "#a17418"))
        case "DROP": return (Color.signalDown.opacity(0.14), Color.signalDown)
        case "AMRAP":return (Color(hex: "#2c6da3").opacity(0.14), Color(hex: "#2c6da3"))
        case "FAIL", "FS": return (Color.inkPrimary.opacity(0.12), Color.inkPrimary)
        case "SS":   return (Color.purple.opacity(0.14), Color.purple)
        case "RP":   return (Color.orange.opacity(0.14), Color.orange)
        case "L/R":  return (Color(hex: "#0d8a7a").opacity(0.14), Color(hex: "#0d8a7a"))
        default:     return (Color.inkPrimary.opacity(0.07), Color.inkMuted)
        }
    }

    init(template: WorkoutTemplate,
         groupName: String? = nil,
         siblings: [WorkoutTemplate] = [],
         onStartWorkout: @escaping (WorkoutTemplate) -> Void) {
        self.template = template
        self.groupName = groupName
        self.siblings = siblings
        self.onStartWorkout = onStartWorkout
        self._activeTemplateId = State(initialValue: template.id)
    }

    private var activeTemplate: WorkoutTemplate {
        siblings.first { $0.id == activeTemplateId } ?? template
    }

    private var sortedExercises: [TemplateExercise] {
        activeTemplate.templateExercises.sorted(by: { $0.order < $1.order })
    }

    private var hasDayTabs: Bool { siblings.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            customHeader
            Rectangle().fill(Color.dsHairLine).frame(height: 1)

            if hasDayTabs {
                dayTabsRow
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
            }

            ScrollView {
                VStack(spacing: 0) {
                    exerciseList
                    if isEditing { addExerciseButton }
                    notesSection
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            let url = URL(string: shareData(for: activeTemplate))
            if let url { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { selected in
                let currentCount = activeTemplate.templateExercises.count
                selected.enumerated().forEach { offset, exercise in
                    activeTemplate.templateExercises.append(TemplateExercise(
                        exerciseId: exercise.id,
                        exerciseName: exercise.name,
                        order: currentCount + offset,
                        targetSets: 3,
                        targetReps: nil
                    ))
                }
                showExercisePicker = false
            }
        }
        .sheet(item: $restTimerTarget) { target in
            restTimerSheet(target: target)
        }
    }

    // MARK: - Header

    private var customHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Text("‹")
                    .font(.mono(24, weight: .light))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier(AX.programs.detailBack)

            VStack(alignment: .leading, spacing: 2) {
                if let gName = groupName {
                    Text(gName.uppercased())
                        .font(.spaceMono(9))
                        .tracking(1.2)
                        .foregroundStyle(Color.inkMuted)
                } else {
                    Text("\(sortedExercises.count) EXERCISES · \(activeTemplate.liveWorkouts.count) LOGGED")
                        .font(.spaceMono(9))
                        .tracking(1.2)
                        .foregroundStyle(Color.inkMuted)
                }
                Text(activeTemplate.name.uppercased())
                    .font(.archivo(20, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier(AX.programs.detailTitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isEditing {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isEditing = false }
                } label: {
                    Text("DONE")
                        .font(.archivo(14, weight: .black))
                        .foregroundStyle(Color.canvasBg)
                        .frame(height: 32)
                        .padding(.horizontal, 14)
                        .background(Color.oreAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.programs.detailDone)
            } else {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { isEditing = true }
                    } label: {
                        Text("EDIT")
                            .font(.archivo(14, weight: .black))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(height: 32)
                            .padding(.horizontal, 14)
                            .background(Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AX.programs.detailEdit)

                    Button { onStartWorkout(activeTemplate) } label: {
                        Text("START")
                            .font(.archivo(16, weight: .black))
                            .foregroundStyle(Color.canvasBg)
                            .frame(height: 32)
                            .padding(.horizontal, 14)
                            .background(Color.oreAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AX.programs.detailStart)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Day Tabs

    private var dayTabsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(siblings.enumerated()), id: \.element.id) { idx, sibling in
                    let isActive = sibling.id == activeTemplateId
                    let label = dayTabLabel(for: sibling, index: idx)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeTemplateId = sibling.id
                            expandedExercises = []
                        }
                    } label: {
                        Text(label)
                            .font(.spaceMono(9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(isActive ? .white : Color.inkMuted)
                            .frame(height: 32)
                            .padding(.horizontal, 12)
                            .background(isActive ? Color.oreAccent : Color.surf)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(isActive ? Color.accentInk : Color.dsHairLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func dayTabLabel(for t: WorkoutTemplate, index: Int) -> String {
        let first = t.name.components(separatedBy: " ").first?.uppercased() ?? "DAY"
        return "\(first) \(index + 1)"
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        Group {
            if !sortedExercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { i, ex in
                        exerciseRow(ex: ex, isLast: i == sortedExercises.count - 1)
                    }
                }
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.dsHairLine, lineWidth: 1))
                .padding(.top, 16)
                .padding(.horizontal, 16)
            }
        }
    }

    private func exerciseRow(ex: TemplateExercise, isLast: Bool) -> some View {
        let isExpanded = expandedExercises.contains(ex.id)
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedExercises.remove(ex.id) }
                    else { expandedExercises.insert(ex.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle().fill(Color.inkPrimary.opacity(0.3)).frame(width: 12, height: 1.5)
                        }
                    }
                    .padding(.trailing, 2)

                    Circle().fill(Color.oreAccent.opacity(0.35)).frame(width: 8, height: 8)

                    Text(ex.exerciseName)
                        .font(.archivo(13, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        statPill(value: "\(ex.targetSets)", label: "SETS")
                        if let reps = ex.targetReps {
                            Text("×").font(.spaceMono(10)).foregroundStyle(Color.inkFaint)
                            statPill(value: "\(reps)", label: "REPS")
                        }
                        if let rir = ex.targetRIR {
                            Text("·").font(.spaceMono(10)).foregroundStyle(Color.inkFaint)
                            statPill(value: "\(rir)", label: "RIR")
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(isExpanded ? Color.oreAccent.opacity(0.05) : Color.clear)
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedSetDetail(ex: ex)
            }

            if !isLast {
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
            }
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.archivo(16, weight: .black))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            Text(label)
                .font(.spaceMono(7))
                .tracking(0.8)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(minWidth: 28)
    }

    // MARK: - Expanded Set Detail

    private func expandedSetDetail(ex: TemplateExercise) -> some View {
        let showRIR = ex.targetRIR != nil
        return VStack(spacing: 0) {
            // Column header
            HStack(spacing: 0) {
                Text("TYPE").frame(width: 52, alignment: .leading)
                Text("#").frame(width: 28, alignment: .center)
                Text("REPS").frame(maxWidth: .infinity, alignment: .center)

                // + RIR chip button
                Button {
                    if showRIR {
                        guard isEditing else { return }
                        mutateExercise(id: ex.id) { $0.targetRIR = nil }
                    } else {
                        guard isEditing else { return }
                        mutateExercise(id: ex.id) { $0.targetRIR = 2 }
                    }
                } label: {
                    HStack(spacing: 3) {
                        if showRIR {
                            Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                            Text("RIR")
                        } else {
                            Text("+ RIR")
                        }
                    }
                    .font(.spaceMono(8, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(showRIR ? Color.accentInk : (isEditing ? Color.accentInk : Color.inkFaint))
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(showRIR ? Color.oreAccent.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(
                        showRIR ? Color.accentInk.opacity(0.4) : (isEditing ? Color.accentInk.opacity(0.4) : Color.clear),
                        lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)

                // REST chip button
                Button {
                    guard isEditing else { return }
                    let secs = ex.restSeconds ?? 90
                    pendingRestSeconds = secs
                    restPickerMinutes = secs / 60
                    restPickerSeconds = (secs % 60 / 5) * 5
                    restTimerTarget = RestTimerTarget(id: ex.id, name: ex.exerciseName)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "timer").font(.system(size: 8, weight: .medium))
                        if let secs = ex.restSeconds {
                            Text(formatRestTime(secs))
                        } else {
                            Text("REST")
                        }
                    }
                    .font(.spaceMono(8, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(ex.restSeconds != nil ? Color.accentInk : (isEditing ? Color.inkMuted : Color.inkFaint))
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(ex.restSeconds != nil ? Color.oreAccent.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(
                        ex.restSeconds != nil ? Color.accentInk.opacity(0.4) : (isEditing ? Color.dsHairLine : Color.clear),
                        lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
            .font(.spaceMono(7)).tracking(1.2).foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(Color.surf2)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            // Set rows
            ForEach(0..<ex.targetSets, id: \.self) { i in
                let type = setType(for: ex, at: i)
                let style = chipStyle(for: type)
                let pickerKey = "\(ex.id):\(i)"
                let pickerOpen = typePickerKey == pickerKey

                VStack(spacing: 0) {
                    SwipeToDeleteRow(
                        onDeleteTapped: {
                            guard isEditing, ex.targetSets > 1 else { return }
                            mutateExercise(id: ex.id) { $0.targetSets -= 1 }
                            var types = setTypesMap[ex.id] ?? []
                            if i < types.count { types.remove(at: i) }
                            setTypesMap[ex.id] = types
                        },
                        rowBackground: Color.surf
                    ) {
                        HStack(spacing: 0) {
                            // TYPE chip
                            Button {
                                guard isEditing else { return }
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    typePickerKey = pickerOpen ? nil : pickerKey
                                }
                            } label: {
                                Text(type)
                                    .font(.spaceMono(7, weight: .bold))
                                    .foregroundStyle(style.fg)
                                    .padding(.horizontal, 5)
                                    .frame(height: 18)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(style.bg))
                                    .frame(width: 52, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Text(String(format: "%02d", i + 1))
                                .font(.spaceMono(9, weight: .bold))
                                .foregroundStyle(Color.inkMuted)
                                .frame(width: 28, alignment: .center)

                            // REPS box
                            ZStack {
                                RoundedRectangle(cornerRadius: 5).fill(Color.surf2)
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.dsHairLine))
                                if isEditing {
                                    TextField("—", text: Binding(
                                        get: { ex.targetReps.map { "\($0)" } ?? "" },
                                        set: { str in mutateExercise(id: ex.id) { $0.targetReps = parseWholeNumber(str) } }
                                    ))
                                    .font(.spaceMono(10, weight: .bold))
                                    .foregroundStyle(Color.inkPrimary)
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                } else {
                                    Text(ex.targetReps.map { "\($0)" } ?? "—")
                                        .font(.spaceMono(10, weight: .bold))
                                        .foregroundStyle(ex.targetReps != nil ? Color.inkPrimary : Color.inkFaint)
                                }
                            }
                            .frame(height: 28).frame(maxWidth: .infinity).padding(.horizontal, 4)

                            // RIR box
                            ZStack {
                                RoundedRectangle(cornerRadius: 5).fill(Color.surf2)
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.dsHairLine))
                                if showRIR && isEditing {
                                    TextField("—", text: Binding(
                                        get: { ex.targetRIR.map { "\($0)" } ?? "" },
                                        set: { str in mutateExercise(id: ex.id) { $0.targetRIR = parseWholeNumber(str) } }
                                    ))
                                    .font(.spaceMono(10, weight: .bold))
                                    .foregroundStyle(Color.inkPrimary)
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                } else {
                                    Text(showRIR ? (ex.targetRIR.map { "\($0)" } ?? "—") : "")
                                        .font(.spaceMono(10, weight: .bold))
                                        .foregroundStyle(ex.targetRIR != nil ? Color.inkPrimary : Color.inkFaint)
                                }
                            }
                            .frame(height: 28).frame(maxWidth: .infinity).padding(.horizontal, 4)
                            .opacity(showRIR ? 1 : 0)

                            Spacer().frame(width: 16)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }

                    // Inline type picker
                    if pickerOpen {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Self.setTypeOptions, id: \.id) { opt in
                                    let s = chipStyle(for: opt.id)
                                    let isSelected = type == opt.id
                                    Button {
                                        updateSetType(exerciseId: ex.id, at: i, newType: opt.id, totalSets: ex.targetSets)
                                        withAnimation(.easeInOut(duration: 0.15)) { typePickerKey = nil }
                                    } label: {
                                        Text(opt.id)
                                            .font(.spaceMono(8, weight: .bold))
                                            .foregroundStyle(isSelected ? .white : s.fg)
                                            .padding(.horizontal, 9)
                                            .frame(height: 26)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.oreAccent : s.bg))
                                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSelected ? Color.accentInk : Color.dsHairLine))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 42)
                        .background(Color.surf2)
                        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }
                }
            }

            if isEditing {
                Button {
                    mutateExercise(id: ex.id) { $0.targetSets += 1 }
                } label: {
                    Text("+ ADD SET")
                        .font(.spaceMono(9)).tracking(0.8).foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.inkFaint))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Color.surf)
            }
        }
    }

    // MARK: - Add Exercise Button

    private var addExerciseButton: some View {
        Button { showExercisePicker = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                Text("ADD EXERCISE").font(.spaceMono(10)).tracking(1)
            }
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(Color.inkFaint))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.programs.detailAddExercise)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        Group {
            if isEditing || !activeTemplate.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOTES")
                        .font(.spaceMono(8, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.inkMuted)

                    if isEditing {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.surf)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))

                            if activeTemplate.notes.isEmpty {
                                Text("Add workout notes, focus cues, reminders…")
                                    .font(.archivo(13))
                                    .foregroundStyle(Color.inkFaint)
                                    .padding(10)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: Binding(
                                get: { activeTemplate.notes },
                                set: { activeTemplate.notes = $0 }
                            ))
                            .font(.archivo(13))
                            .foregroundStyle(Color.inkPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .frame(minHeight: 80)
                        }
                    } else {
                        Text("\"\(activeTemplate.notes)\"")
                            .font(.archivo(13))
                            .italic()
                            .foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Rest Timer Sheet

    private func restTimerSheet(target: RestTimerTarget) -> some View {
        let presets: [(label: String, seconds: Int)] = [
            ("OFF", 0),    ("0:30", 30),   ("1:00", 60),   ("1:30", 90),
            ("2:00", 120), ("2:30", 150),  ("3:00", 180),  ("3:30", 210),
            ("4:00", 240), ("5:00", 300),  ("7:00", 420),  ("10:00", 600),
        ]
        let minuteOptions = Array(0...10)
        let secondOptions = stride(from: 0, through: 55, by: 5).map { $0 }

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("REST TIMER")
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                Text(target.name)
                    .font(.archivo(20, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 16)

            // Preset grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(presets, id: \.seconds) { p in
                    let isSelected = pendingRestSeconds == p.seconds
                    Button {
                        pendingRestSeconds = p.seconds
                        restPickerMinutes = p.seconds / 60
                        restPickerSeconds = p.seconds % 60
                    } label: {
                        Text(p.label)
                            .font(.spaceMono(11, weight: .bold))
                            .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isSelected ? Color.oreAccent : Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                                isSelected ? Color.accentInk : Color.dsHairLine, lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.94))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            // Drum picker
            HStack(spacing: 0) {
                Picker("MIN", selection: Binding(
                    get: { restPickerMinutes },
                    set: { v in
                        restPickerMinutes = v
                        pendingRestSeconds = v * 60 + restPickerSeconds
                    }
                )) {
                    ForEach(minuteOptions, id: \.self) { m in
                        Text("\(m)").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Text(":")
                    .font(.archivo(32, weight: .black))
                    .foregroundStyle(Color.inkPrimary)

                Picker("SEC", selection: Binding(
                    get: { restPickerSeconds },
                    set: { v in
                        restPickerSeconds = v
                        pendingRestSeconds = restPickerMinutes * 60 + v
                    }
                )) {
                    ForEach(secondOptions, id: \.self) { s in
                        Text(String(format: "%02d", s)).tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 160)
            .padding(.horizontal, 16)

            HStack {
                Text("MIN").frame(maxWidth: .infinity)
                Spacer().frame(width: 32)
                Text("SEC").frame(maxWidth: .infinity)
            }
            .font(.spaceMono(9))
            .tracking(1.2)
            .foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 40)
            .padding(.bottom, 16)

            // Save
            Button {
                mutateExercise(id: target.id) { $0.restSeconds = pendingRestSeconds == 0 ? nil : pendingRestSeconds }
                restTimerTarget = nil
            } label: {
                Text("SAVE")
                    .font(.archivo(15, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.oreAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(620)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvasBg)
    }

    // MARK: - Helpers

    private func mutateExercise(id: UUID, mutation: (inout TemplateExercise) -> Void) {
        guard let idx = activeTemplate.templateExercises.firstIndex(where: { $0.id == id }) else { return }
        var ex = activeTemplate.templateExercises[idx]
        mutation(&ex)
        activeTemplate.templateExercises[idx] = ex
    }

    private func formatRestTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func shareData(for t: WorkoutTemplate) -> String {
        TemplateShareService.shareURLString(for: t)
    }
}
