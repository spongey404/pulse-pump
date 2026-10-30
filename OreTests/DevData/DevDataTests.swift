import Testing
import Foundation
import SwiftData
@testable import Ore

@MainActor
struct DevDataTests {
    /// Fixed "now" (a Wednesday) so history is identical on every run.
    private static var now: Date {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 7; c.hour = 20
        return Calendar(identifier: .iso8601).date(from: c)!
    }

    private func config(_ s: DevDataConfig.Scenario = .busy, seed: UInt64 = 42, weeks: Int = 12) -> DevDataConfig {
        var c = DevDataConfig()
        c.scenario = s; c.seed = seed; c.weeks = weeks; c.reset = true; c.now = Self.now
        c.calendar = Calendar(identifier: .iso8601)
        return c
    }

    private func run(_ c: DevDataConfig) throws -> (ModelContext, DevDataService.Summary) {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        return (ctx, DevDataService.run(c, modelContext: ctx))
    }

    @Test func seededRandomIsDeterministic() {
        var a = SeededRandom(seed: 7), b = SeededRandom(seed: 7), c = SeededRandom(seed: 8), d = SeededRandom(seed: 7)
        #expect((0..<10).map { _ in a.next() } == (0..<10).map { _ in b.next() })
        #expect(a.unit() >= 0 && a.unit() < 1)
        #expect(c.next() != d.next())
    }

    @Test func sameSeedGivesSameHistory() throws {
        let (c1, s1) = try run(config())
        let (c2, s2) = try run(config())
        #expect(s1.workouts == s2.workouts && s1.sets == s2.sets)
        let d1 = try c1.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)])).map(\.date)
        let d2 = try c2.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)])).map(\.date)
        #expect(d1 == d2)
    }

    @Test func differentSeedChangesHistory() throws {
        let (_, a) = try run(config(seed: 1))
        let (_, b) = try run(config(seed: 2))
        #expect(a.sets != b.sets || a.workouts != b.workouts)
    }

    @Test func busyScenarioShape() throws {
        let (ctx, s) = try run(config())
        #expect(s.workouts > 40 && s.workouts <= 72)       // ~5/wk over 12 weeks, some skipped
        #expect(s.templates == 3 && s.bodyweightDays > 0 && s.prs > 0)
        let user = try #require(try ctx.fetch(FetchDescriptor<User>()).first)
        #expect(user.selectedSplit?.days.count == 6)
        #expect(user.equipmentProfiles.count == 2)
        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        #expect(workouts.allSatisfy { !$0.isDraft && $0.date <= Self.now })
        // No seeded skips in the last 7 days, so there is always a session within the streak window.
        let recent = workouts.filter { Self.now.timeIntervalSince($0.date) < 7 * 86400 }
        #expect(recent.count >= 4)
    }

    @Test func historyIsLinkedAndSane() throws {
        let (ctx, _) = try run(config())
        let logs = try ctx.fetch(FetchDescriptor<ExerciseLog>())
        #expect(!logs.isEmpty && logs.allSatisfy { $0.exercise != nil && $0.workout != nil })     // no orphaned exercise links
        let sets = try ctx.fetch(FetchDescriptor<SetLog>())
        #expect(sets.allSatisfy { $0.reps > 0 && $0.weight > 0 })
        #expect(sets.contains { $0.setType == .warmup } && sets.contains { $0.setType == .standard })
        let templates = try ctx.fetch(FetchDescriptor<WorkoutTemplate>())
        let exerciseIds = Set(try ctx.fetch(FetchDescriptor<Exercise>()).map(\.id))
        #expect(templates.flatMap(\.templateExercises).allSatisfy { exerciseIds.contains($0.exerciseId) })   // real ids
    }

    @Test func progressiveOverloadAndDeload() throws {
        let lift = DevDay.push.lifts[0]                                   // bench
        let w0 = DevDataFactory.topWeight(lift, week: 0, deloadWeek: nil)
        let w10 = DevDataFactory.topWeight(lift, week: 10, deloadWeek: nil)
        #expect(w10 > w0)
        let deload = DevDataFactory.topWeight(lift, week: 7, deloadWeek: 7)
        #expect(deload < DevDataFactory.topWeight(lift, week: 6, deloadWeek: 7))
        #expect(DevDataFactory.roundToPlate(81.3) == 81.25)
    }

    @Test func lapsedScenarioHasNoRecentWorkouts() throws {
        let (ctx, _) = try run(config(.lapsed))
        let latest = try #require(try ctx.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])).first)
        #expect(Self.now.timeIntervalSince(latest.date) > 11 * 86400)
    }

    @Test func newUserHasNoWorkouts() throws {
        let (ctx, s) = try run(config(.newUser))
        let workoutCount = try ctx.fetchCount(FetchDescriptor<Workout>())
        let userCount = try ctx.fetchCount(FetchDescriptor<User>())
        #expect(s.workouts == 0 && workoutCount == 0)
        #expect(userCount == 1)
    }

    @Test func draftFlagAddsOneInProgressWorkout() throws {
        var c = config(); c.draft = true
        let (ctx, _) = try run(c)
        let drafts = try ctx.fetchCount(FetchDescriptor<Workout>(predicate: #Predicate { $0.isDraft }))
        #expect(drafts == 1)
    }

    @Test func skipsWhenUserExistsUnlessReset() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        var c = config(); c.reset = true
        _ = DevDataService.run(c, modelContext: ctx)
        c.reset = false
        #expect(DevDataService.run(c, modelContext: ctx).skipped)
        c.reset = true
        let again = DevDataService.run(c, modelContext: ctx)
        #expect(!again.skipped)
        let users = try ctx.fetchCount(FetchDescriptor<User>())
        #expect(users == 1)          // reset didn't duplicate the user
    }
}
