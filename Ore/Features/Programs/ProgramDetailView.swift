import SwiftUI

/// A program (Ore Programs 05, 10): ‹ PROGRAM + name, EDIT; the meta line; the week strip (weekday + workout number, the next workout's day in
/// the accent); WORKOUTS in order with NEXT marked, each workout's exercises, and a START on the right: accent for the next one, outlined for
/// the others, "+ EXERCISES" for an empty one.
struct ProgramDetailView: View {
    let program: ProgramSummary
    let onBack: () -> Void
    let onEdit: () -> Void
    let onOpenWorkout: (WorkoutTemplate, Bool) -> Void
    let onStart: (WorkoutTemplate) -> Void

    private var next: (index: Int, template: WorkoutTemplate)? { ProgramPlan.nextWorkout(of: program) }

    private var meta: String {
        var m = ProgramPlan.metaLine(workouts: program.workouts.count, days: program.days.count)
        if let used = ProgramPlan.lastUsed(program) { m += " · \(SocialAge.short(used) == "NOW" ? "JUST NOW" : SocialAge.short(used) + " AGO")" }
        return m
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgramPageHeader(kicker: "PROGRAM", title: program.name.uppercased(), onBack: onBack) {
                ProgramOutlineButton(title: "EDIT", id: AX.programs.editProgram, action: onEdit)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(meta).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        ProgramWeekTiles(days: program.days, workoutCount: program.workouts.count, nextWeekday: nextWeekday)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
                    ProgramSectionRow(left: "WORKOUTS", right: "ROTATE IN ORDER")
                    VStack(spacing: 0) {
                        ForEach(Array(program.workouts.enumerated()), id: \.element.id) { i, t in workoutRow(i, t) }
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    ProgramDashedAdd(title: "+ ADD WORKOUT", id: AX.programs.detailAddWorkout) { addWorkout() }.padding(.horizontal, 16).padding(.top, 12)
                    Color.clear.frame(height: 20)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The weekday the next workout falls on: the next training day from today.
    private var nextWeekday: Int? {
        let today = program.workouts.flatMap(\.liveWorkouts).contains { Calendar.current.isDateInToday($0.date) }
        return ProgramPlan.nextTrainingDay(from: Date(), days: program.days, trainedToday: today)?.weekday
    }

    @Environment(\.modelContext) private var modelContext

    private func addWorkout() {
        var d = ProgramStore.draft(for: program)
        d.addWorkout()
        ProgramStore.save(d, modelContext: modelContext)
    }

    private func workoutRow(_ i: Int, _ t: WorkoutTemplate) -> some View {
        let isNext = next?.index == i
        let days = ProgramPlan.weekdays(ofWorkout: i, days: program.days, workoutCount: program.workouts.count)
        let exercises = t.templateExercises.sorted { $0.order < $1.order }
        var metaParts: [String] = []
        if exercises.isEmpty { metaParts = ["EMPTY"] } else {
            if !days.isEmpty { metaParts.append(ProgramPlan.weekdayText(days)) }
            metaParts.append("\(exercises.count) EX")
            if let avg = ProgramPlan.averageMinutes(for: t) { metaParts.append("AVG \(avg) MIN") }
        }
        return HStack(alignment: .top, spacing: 12) {
            Button { onOpenWorkout(t, false) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%02d", i + 1)).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        Text(t.name.uppercased()).font(.archivo(17, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        if isNext { Text("NEXT").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk) }
                    }
                    Text(metaParts.joined(separator: " · ")).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.top, 5)
                    VStack(spacing: 3) {
                        ForEach(Array(exercises.prefix(5).enumerated()), id: \.element.id) { _, e in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(e.exerciseName.exerciseTitleCase).font(.archivo(13)).foregroundStyle(Color.inkSecondary).lineLimit(1)
                                Spacer(minLength: 0)
                                Text(ProgramPlan.targetText(e)).font(.spaceMono(10, weight: .bold)).foregroundStyle(Color.inkMuted)
                            }
                        }
                        if exercises.count > 5 {
                            Text("+\(exercises.count - 5) MORE").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, exercises.isEmpty ? 0 : 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.programs.workoutRow(i))
            startButton(i, t, isNext: isNext, empty: exercises.isEmpty)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    @ViewBuilder private func startButton(_ i: Int, _ t: WorkoutTemplate, isNext: Bool, empty: Bool) -> some View {
        if empty {
            Button { onOpenWorkout(t, true) } label: { label("+ EXERCISES", filled: false) }.buttonStyle(PressOpacityButtonStyle()).accessibilityIdentifier(AX.programs.workoutStart(i))
        } else {
            Button { onStart(t) } label: { label("START", filled: isNext) }.buttonStyle(PressOpacityButtonStyle()).accessibilityIdentifier(AX.programs.workoutStart(i))
        }
    }

    private func label(_ text: String, filled: Bool) -> some View {
        Text(text).font(.archivo(12, weight: .black)).tracking(0.6).foregroundStyle(filled ? Color.white : Color.inkPrimary)
            .padding(.horizontal, 12).frame(height: 36)
            .background { if filled { AccentFill(priority: 5) } else { Color.clear } }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { if !filled { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1) } }
    }
}
