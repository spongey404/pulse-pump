import Testing
import Foundation
import SwiftData
@testable import Ore

// Shared factories for the emulator tier: realistic data built with the same helpers the unit tests use
// (`SyncDevice` builders, `DevDataService` for the 90-workout history), never hand-written JSON.

/// A simulated phone whose sync engine talks to the real Firestore emulator instead of the in-memory cloud.
extension SyncDevice {
    /// A new, empty phone signed in as `account` (initial sync not yet run).
    static func phone(for account: TestAccount, pageSize: Int? = nil, batchSize: Int? = nil) throws -> SyncDevice {
        let device = try SyncDevice.make(uid: account.uid, start: false, pageSize: pageSize)
        if let batchSize { device.service.config.batchSize = batchSize }
        device.service.start(uid: account.uid, context: device.ctx, remote: account.store, triggerSync: false)
        return device
    }

    /// Edits a workout the way the UI does (stamps it dirty), then saves.
    func edit(_ workout: Workout, _ change: (Workout) -> Void) throws {
        change(workout)
        workout.markUpdated()
        try ctx.save()
    }

    /// The signed-in user's mirror of the dev-data bodyweight log (DevData writes the App Group; copy it to this phone).
    func adoptDevDataBodyweight() {
        if let data = OreWidgetStore.defaults?.data(forKey: BodyweightLog.key) { bodyweight.set(data, forKey: BodyweightLog.key) }
    }
}

/// What a restored phone has to match on the phone that pushed.
struct HistoryTotals: Equatable {
    var workouts = 0, logs = 0, sets = 0, workingSets = 0, templates = 0, equipment = 0
    var volume = 0.0, duration = 0.0, calories = 0.0
    var exerciseNames: [String] = []

    @MainActor
    init(_ d: SyncDevice) {
        let ws = d.fetch(Workout.self).filter(\.isHistory)
        workouts = ws.count
        logs = ws.flatMap(\.exerciseLogs).count
        sets = ws.flatMap(\.exerciseLogs).flatMap(\.sets).count
        workingSets = ws.reduce(0) { $0 + $1.workingSetCount }
        volume = (ws.reduce(0) { $0 + $1.workingVolume } * 1000).rounded() / 1000
        duration = ws.reduce(0) { $0 + $1.duration }
        calories = ws.reduce(0) { $0 + $1.calorieBurnEstimate }
        templates = d.fetch(WorkoutTemplate.self).count
        equipment = d.fetch(EquipmentProfile.self).count
        exerciseNames = ws.flatMap(\.exerciseLogs).compactMap { $0.exercise?.name }.sorted()
    }
}

@MainActor
enum IntegrationData {
    /// The ~90-workout "busy lifter" history from the DEBUG dev-data generator, written into `device`.
    @discardableResult
    static func busyHistory(into device: SyncDevice, weeks: Int = 20, seed: UInt64 = 42) -> DevDataService.Summary {
        var c = DevDataConfig()
        c.scenario = .busy; c.seed = seed; c.weeks = weeks; c.reset = true
        var parts = DateComponents(); parts.year = 2026; parts.month = 10; parts.day = 7; parts.hour = 20
        c.calendar = Calendar(identifier: .iso8601)
        c.now = c.calendar.date(from: parts)!
        let summary = DevDataService.run(c, modelContext: device.ctx)
        device.adoptDevDataBodyweight()
        return summary
    }

    /// `count` one-set workouts on distinct days, spread into the past.
    static func lightWorkouts(_ count: Int, on device: SyncDevice) {
        let exercise = device.exercise("Back Squat")
        for i in 0..<count {
            let w = Workout(date: Date().addingTimeInterval(-Double(i + 1) * 3_600), duration: 1_800, calorieBurnEstimate: 150, isDraft: false)
            device.ctx.insert(w)
            let log = ExerciseLog(order: 0)
            device.ctx.insert(log); log.workout = w; log.exercise = exercise
            let set = SetLog(order: 0, weight: 60 + Double(i % 10), reps: 5, rir: 2, setType: .standard)
            device.ctx.insert(set); set.exerciseLog = log
        }
        try? device.ctx.save()
    }

    // MARK: Social

    static func post(by account: TestAccount, id: String = UUID().uuidString.lowercased(),
                     audience: PostAudience = .friends, bodyMapAudience: PostAudience = .friends,
                     name: String = "Push Day", caption: String = "", minutesAgo: Double = 0,
                     muscleSets: [String: Int]? = nil) -> PostPayload {
        let bench = FeedExercise(id: UUID().uuidString, name: "Barbell Bench Press", sets: [
            FeedSetLog(weight: 60, reps: 8, duration: 0, distance: 0, setType: "warmup", side: nil),
            FeedSetLog(weight: 100, reps: 5, duration: 0, distance: 0, setType: "standard", side: nil),
            FeedSetLog(weight: 102.5, reps: 3, duration: 0, distance: 0, setType: "standard", side: nil),
        ], improvementScore: 1.5, primaryMuscles: ["chest"], secondaryMuscles: ["triceps"])
        return PostPayload(
            postId: id, authorUid: account.uid, authorName: account.displayName, authorUsername: account.handle,
            date: Date().addingTimeInterval(-minutesAgo * 60), workoutName: name, audience: audience,
            bodyMapAudience: bodyMapAudience,
            stats: .init(sets: 2, volumeKg: 807.5, durationSec: 3_300, prCount: 1),
            exercises: [bench], caption: caption, taggedUids: [], muscleSets: muscleSets)
    }

    /// A challenge that is running now (started two days ago, ends in five).
    static func challenge(metric: ChallengeMetric = .totalVolume, name: String = "Volume Week",
                          exerciseName: String? = nil, visibility: ChallengeVisibility = .invite) -> ChallengeDraft {
        ChallengeDraft(name: name, metric: metric, exerciseName: exerciseName,
                       startAt: Date().addingTimeInterval(-2 * 86_400), endAt: Date().addingTimeInterval(5 * 86_400),
                       visibility: visibility)
    }

    /// Logs one finished session for `account` (through the real sync path, which is what triggers
    /// `onWorkoutWritten`) and returns the volume of its working sets in kg.
    @discardableResult
    static func logWorkout(for account: TestAccount, sets: [(Double, Int)] = [(100, 5), (100, 5), (102.5, 3)],
                           daysAgo: Int = 1) async throws -> Double {
        let phone = try SyncDevice.phone(for: account)
        let bench = phone.exercise("Barbell Bench Press")
        phone.user(name: account.displayName)
        phone.workout(daysAgo: daysAgo, exercise: bench, sets: sets)
        try phone.ctx.save()
        await phone.sync()
        // SyncDevice.workout marks the first set a warm-up: it never counts.
        return sets.dropFirst().reduce(0) { $0 + $1.0 * Double($1.1) }
    }
}

extension RemoteStore {
    /// Every document of a collection (pages through `fetchChanged` like the sync pull does).
    func allDocs(_ collection: SyncCollection, pageSize: Int = 200) async throws -> [RemoteDoc] {
        var out: [RemoteDoc] = []
        var after: RemoteCursor?
        while true {
            let page = try await fetchChanged(collection, sinceMs: 0, limit: pageSize, after: after)
            out += page
            guard page.count == pageSize, let last = page.last else { return out }
            after = RemoteCursor(updatedAtMs: last.updatedAtMs, docId: last.id)
        }
    }
}
