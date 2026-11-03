import SwiftUI
import SwiftData

/// The Programs tab (Ore Programs 01, 14): PROGRAMS + the bordered "+", an UP NEXT card (the only accent button on the tab), and
/// YOUR PROGRAMS, each with its week. The tab owns its navigation: Start from, New / Edit program, Program, Workout and Add exercises.
struct ProgramsTabView: View {
    let onStartFromTemplate: (WorkoutTemplate) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }, sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @State private var path = NavigationPath()

    private var programs: [ProgramSummary] { ProgramPlan.programs(from: templates) }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: ProgramRoute.self) { destination($0) }
        }
    }

    // MARK: Root

    private var root: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    if programs.isEmpty {
                        emptyState
                    } else {
                        if let up = ProgramPlan.upNext(programs) { upNextCard(up) }
                        ProgramSectionRow(left: "YOUR PROGRAMS", right: "\(programs.count)")
                        VStack(spacing: 0) {
                            ForEach(programs) { p in programRow(p) }
                        }
                        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("PROGRAMS").font(.archivo(28, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary)
                .accessibilityIdentifier(AX.programs.screen)
            Spacer()
            Button { path.append(ProgramRoute.startFrom) } label: {
                Text("+").font(.archivo(26)).foregroundStyle(Color.inkPrimary).frame(width: 44, height: 44)
                    .background(Color.surf, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle()).accessibilityLabel("New program").accessibilityIdentifier(AX.programs.add)
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 56)
            Text("NO PROGRAMS").font(.archivo(32, weight: .black)).tracking(1).foregroundStyle(Color.inkFaint).accessibilityIdentifier(AX.programs.empty)
            Text("Tap + to start a program: workouts that take turns on your training days.").font(.archivo(13)).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24).frame(maxWidth: .infinity)
    }

    // MARK: UP NEXT

    private func upNextCard(_ up: ProgramPlan.UpNext) -> some View {
        let (p, index, t, empty): (ProgramSummary, Int, WorkoutTemplate, Bool) = {
            switch up { case .workout(let p, let i, let t): (p, i, t, false); case .allEmpty(let p, let i, let t): (p, i, t, true) }
        }()
        let when = ProgramPlan.nextTrainingDay(from: Date(), days: p.days, trainedToday: Self.trainedToday(p))
        let whenText = when.map { $0.isToday ? "TODAY" : (ProgramPlan.weekdayNames[$0.weekday] ?? "") } ?? ""
        var meta = "DAY \(index + 1) OF \(p.workouts.count) · \(t.templateExercises.count) EXERCISE\(t.templateExercises.count == 1 ? "" : "S")"
        if let avg = ProgramPlan.averageMinutes(for: t) { meta += " · AVG \(avg) MIN" }
        let names = t.templateExercises.sorted { $0.order < $1.order }.map { $0.exerciseName.exerciseTitleCase }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("UP NEXT" + (whenText.isEmpty ? "" : " · \(whenText)")).font(.spaceMono(9, weight: .bold)).tracking(2).foregroundStyle(Color.accentInk)
                Spacer()
                Text(p.name.uppercased()).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(t.name.uppercased()).font(.archivo(26, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary).lineLimit(2)
                Text(meta).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            }
            if !names.isEmpty {
                Text(names.joined(separator: " · ")).font(.archivo(13)).foregroundStyle(Color.inkSecondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
            Button {
                if empty { path.append(ProgramRoute.workout(t.id, edit: true)) } else { onStartFromTemplate(t) }
            } label: {
                HStack {
                    Text(empty ? "ADD EXERCISES" : "START WORKOUT").font(.archivo(16, weight: .black)).tracking(0.6)
                    Spacer()
                    Text("›").font(.archivo(22, weight: .black))
                }
                .foregroundStyle(.white).padding(.horizontal, 18).frame(height: 52).frame(maxWidth: .infinity)
                .background { AccentFill(priority: 5) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressOpacityButtonStyle()).accessibilityIdentifier(AX.programs.upNextStart)
        }
        .padding(14)
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain).accessibilityIdentifier(AX.programs.upNext)
    }

    private static func trainedToday(_ p: ProgramSummary) -> Bool {
        p.workouts.flatMap(\.liveWorkouts).contains { Calendar.current.isDateInToday($0.date) }
    }

    // MARK: YOUR PROGRAMS

    private func programRow(_ p: ProgramSummary) -> some View {
        var meta = ProgramPlan.metaLine(workouts: p.workouts.count, days: p.days.count)
        if let used = ProgramPlan.lastUsed(p) { meta += " · \(SocialAge.short(used) == "NOW" ? "JUST NOW" : SocialAge.short(used) + " AGO")" }
        return Button { path.append(ProgramRoute.program(p.id)) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(p.name.uppercased()).font(.archivo(17, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                    Text(meta).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(1)
                    ProgramMiniWeek(days: p.days)
                }
                Spacer(minLength: 0)
                Text("›").font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkGhost)
            }
            .padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .buttonStyle(OreRowPressStyle())
        .accessibilityIdentifier(AX.programs.row(p.name))
    }

    // MARK: Destinations

    @ViewBuilder private func destination(_ route: ProgramRoute) -> some View {
        switch route {
        case .startFrom:
            StartFromView(onBack: { path.removeLast() }, onPick: { choice in path.append(ProgramRoute.newProgram(choice: choice)) })
        case .newProgram(let choice):
            ProgramFormView(draft: ProgramTemplates.all.first { $0.id == choice }?.draft() ?? ProgramDraft(),
                            title: (ProgramTemplates.all.first { $0.id == choice }?.name ?? "Blank").uppercased(),
                            onBack: { path.removeLast() },
                            onSaved: { id in path = NavigationPath(); path.append(ProgramRoute.program(id)) },
                            onDeleted: {})
        case .editProgram(let id):
            if let p = programs.first(where: { $0.id == id }) {
                ProgramFormView(draft: ProgramStore.draft(for: p), onBack: { path.removeLast() },
                                onSaved: { _ in path.removeLast() },
                                onDeleted: { path = NavigationPath() })
            }
        case .program(let id):
            if let p = programs.first(where: { $0.id == id }) {
                ProgramDetailView(program: p, onBack: { path.removeLast() },
                                  onEdit: { path.append(ProgramRoute.editProgram(id)) },
                                  onOpenWorkout: { t, edit in path.append(ProgramRoute.workout(t.id, edit: edit)) },
                                  onStart: onStartFromTemplate)
            }
        case .workout(let id, let edit):
            if let t = templates.first(where: { $0.id == id }) {
                ProgramWorkoutView(template: t, program: programs.first { $0.id == t.programId }, startsEditing: edit || t.templateExercises.isEmpty,
                                   onBack: { path.removeLast() }, onAddExercises: { path.append(ProgramRoute.addExercises(workout: id)) }, onStart: onStartFromTemplate)
            }
        case .addExercises(let id):
            if let t = templates.first(where: { $0.id == id }) {
                ProgramAddExercisesView(template: t, onBack: { path.removeLast() }, onDone: { path.removeLast() })
            }
        }
    }
}
