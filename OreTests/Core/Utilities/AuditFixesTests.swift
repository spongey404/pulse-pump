import Testing
import Foundation
import SwiftData
@testable import Ore

/// Regression tests for the audit follow-ups: Monday weeks, tracked-muscle dedupe, Live Activity
/// dedupe, template share-via-link.
@MainActor
struct AuditFixesTests {

    // MARK: Monday week maths (Home "this week" must not follow the locale's first weekday)

    private func calendar(firstWeekday: Int) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = firstWeekday
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func weekStartIsMondayRegardlessOfLocale() {
        for firstWeekday in [1, 2, 7] {   // US, ISO, Middle East locales
            let cal = calendar(firstWeekday: firstWeekday)
            let sunday = date(2026, 10, 11, cal)       // Sunday
            let monday = date(2026, 10, 5, cal)
            let wed = date(2026, 10, 7, cal)
            let expected = cal.startOfDay(for: monday)
            #expect(WeekMath.mondayWeekStart(of: sunday, calendar: cal) == expected)
            #expect(WeekMath.mondayWeekStart(of: monday, calendar: cal) == expected)
            #expect(WeekMath.mondayWeekStart(of: wed, calendar: cal) == expected)
        }
    }

    @Test func weeksAgoCountsMondayWeeks() {
        let cal = calendar(firstWeekday: 1)
        let now = date(2026, 10, 7, cal)   // Wednesday
        #expect(WeekMath.weeksAgo(date(2026, 10, 5, cal), now: now, calendar: cal) == 0)
        #expect(WeekMath.weeksAgo(date(2026, 10, 4, cal), now: now, calendar: cal) == 1)   // Sunday before
        #expect(WeekMath.weeksAgo(date(2026, 9, 14, cal), now: now, calendar: cal) == 3)
        #expect(WeekMath.weeksAgo(date(2026, 9, 13, cal), now: now, calendar: cal) == 4)   // outside a 4-week scrubber
    }

    // MARK: Body tab: generic .shoulders / .back must not double count

    private let tracked: Set<MuscleGroup> = [
        .chest, .lats, .quads, .frontDelts, .sideDelts, .rearDelts, .biceps, .triceps, .traps, .upperBack, .lowerBack,
    ]

    @Test func genericGroupDroppedWhenSpecificChildPresent() {
        // Overhead Press: [.shoulders, .frontDelts] credited side delts AND front delts before.
        #expect(MuscleGroup.trackedGroups([.shoulders, .frontDelts], tracked: tracked) == [.frontDelts])
        // Arnold Press listed side delts twice (once via .shoulders).
        #expect(MuscleGroup.trackedGroups([.shoulders, .frontDelts, .sideDelts], tracked: tracked) == [.frontDelts, .sideDelts])
        // Chest-supported row: [.back, .upperBack]; Barbell row: [.back, .lats].
        #expect(MuscleGroup.trackedGroups([.back, .upperBack], tracked: tracked) == [.upperBack])
        #expect(MuscleGroup.trackedGroups([.back, .lats], tracked: tracked) == [.lats])
    }

    @Test func genericGroupFallsBackWhenAlone() {
        #expect(MuscleGroup.trackedGroups([.shoulders], tracked: tracked) == [.sideDelts])
        #expect(MuscleGroup.trackedGroups([.back], tracked: tracked) == [.upperBack])
        // Untracked groups are ignored, duplicates collapse.
        #expect(MuscleGroup.trackedGroups([.chest, .chest, .neck], tracked: tracked) == [.chest])
    }

    // MARK: Live Activity dedupe

    @Test func liveActivityIgnoresPerSecondCounters() {
        func state(elapsed: Int, rest: Int, done: Int = 0) -> WorkoutActivityAttributes.ContentState {
            .init(elapsedSeconds: elapsed, currentExercise: "Bench", completedSets: done, totalSets: 9, restSecondsRemaining: rest)
        }
        let a = state(elapsed: 10, rest: 30)
        #expect(LiveActivityService.isVisiblyUnchanged(state(elapsed: 11, rest: 29), from: a))
        #expect(!LiveActivityService.isVisiblyUnchanged(state(elapsed: 11, rest: 29, done: 1), from: a))
        #expect(!LiveActivityService.isVisiblyUnchanged(a, from: nil))
    }

    // MARK: Template share-via-link

    private func context() throws -> ModelContext {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        for e in ExerciseSeedService.allExercises { ctx.insert(e) }
        return ctx
    }

    @Test func sharePayloadRoundTripsEverythingAndLinksExercises() throws {
        let ctx = try context()
        let bench = try #require(try ctx.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Barbell Bench Press" })
        let source = WorkoutTemplate(name: "My Push", templateExercises: [
            TemplateExercise(exerciseId: UUID(), exerciseName: "Zzz Mystery Lift", order: 1, targetSets: 2, targetReps: 12),
            TemplateExercise(exerciseId: bench.id, exerciseName: bench.name, order: 0, targetSets: 4, targetReps: 6,
                             targetRIR: 2, restSeconds: 150, notes: "pause"),
        ])
        source.notes = "heavy"

        let link = TemplateShareService.shareURLString(for: source)
        let url = try #require(URLComponents(string: link))
        let raw = try #require(url.queryItems?.first { $0.name == "data" }?.value)
        let payload = try #require(TemplateShareService.decode(base64: raw))

        let imported = TemplateShareService.importTemplate(payload, modelContext: ctx)
        #expect(imported.name == "My Push")
        #expect(imported.notes == "heavy")
        let ex = imported.templateExercises.sorted { $0.order < $1.order }
        #expect(ex.map(\.exerciseName) == [bench.name, "Zzz Mystery Lift"])
        #expect(ex[0].exerciseId == bench.id)          // linked by name, not a dangling id
        #expect(ex[0].targetRIR == 2 && ex[0].restSeconds == 150 && ex[0].notes == "pause")   // not lossy
        #expect(ex[1].targetReps == 12 && ex[1].targetSets == 2)
        let custom = try ctx.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
        #expect(custom.map(\.name) == ["Zzz Mystery Lift"])
    }

    @Test func garbageLinkIsRejected() {
        #expect(TemplateShareService.decode(base64: "not base64 at all!!") == nil)
        #expect(TemplateShareService.decode(Data("{}".utf8)) == nil)
    }
}
