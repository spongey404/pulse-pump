import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// One simulated phone: its own in-memory SwiftData store, private UserDefaults and a SyncService wired to a
/// (possibly shared) in-memory cloud. Two devices sharing a `remote` model two phones on one account.
@MainActor
struct SyncDevice {
    let container: ModelContainer
    let ctx: ModelContext
    let remote: InMemoryRemoteStore
    let service: SyncService
    let defaults: UserDefaults
    let bodyweight: UserDefaults
    let uid: String

    static func suite() -> UserDefaults {
        let name = "sync-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    /// `start` wires the service (no automatic sync) so tests drive cycles with `syncNow()`.
    static func make(uid: String = "alice", remote: InMemoryRemoteStore = InMemoryRemoteStore(),
                     start: Bool = true, pageSize: Int? = nil) throws -> SyncDevice {
        let container = try WidgetFixedDataTests.container()
        let ctx = ModelContext(container)
        let defaults = suite(), bw = suite()
        let service = SyncService(defaults: defaults, bodyweightDefaults: bw)
        service.clearsWidgetData = false
        service.sleep = { _ in try? await Task.sleep(for: .seconds(3600)) }   // never retry on its own in tests
        if let pageSize { service.config.pageSize = pageSize }
        let device = SyncDevice(container: container, ctx: ctx, remote: remote, service: service,
                                defaults: defaults, bodyweight: bw, uid: uid)
        if start { service.start(uid: uid, context: ctx, remote: remote, triggerSync: false) }
        return device
    }

    // MARK: Builders

    @discardableResult
    func user(name: String = "Ada", weight: Double = 70) -> User {
        let u = User(name: name, username: name.lowercased(), weight: weight, height: 170, age: 30,
                     gender: .female, unitPreference: .lbs, experienceLevel: .intermediate)
        ctx.insert(u)
        return u
    }

    @discardableResult
    func exercise(_ name: String = "Barbell Bench Press", custom: Bool = false) -> Exercise {
        let e = Exercise(name: name, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], equipmentType: .barbell,
                         movementPattern: .push, isCustom: custom)
        ctx.insert(e)
        return e
    }

    @discardableResult
    func workout(daysAgo: Int = 1, exercise: Exercise, sets: [(Double, Int)] = [(100, 5), (100, 5), (102.5, 3)],
                 template: WorkoutTemplate? = nil, user: User? = nil, draft: Bool = false, notes: String = "") -> Workout {
        let w = Workout(date: Date().addingTimeInterval(-Double(daysAgo) * 86_400), duration: 3_300.5, notes: notes,
                        calorieBurnEstimate: 310, isDraft: draft)
        w.user = user
        w.template = template
        ctx.insert(w)
        let log = ExerciseLog(order: 0, notes: "felt strong")
        ctx.insert(log); log.workout = w; log.exercise = exercise
        for (i, s) in sets.enumerated() {
            let set = SetLog(order: i, weight: s.0, reps: s.1, rir: i == 0 ? 2 : nil,
                             duration: i == 1 ? 45 : nil, distance: i == 2 ? 12.5 : nil,
                             setType: i == 0 ? .warmup : .standard, side: i == 2 ? .left : .both)
            ctx.insert(set); set.exerciseLog = log
        }
        return w
    }

    @discardableResult
    func template(_ name: String = "Push Day", exercise: Exercise? = nil) -> WorkoutTemplate {
        let t = WorkoutTemplate(name: name, templateExercises: exercise.map {
            [TemplateExercise(exerciseId: $0.id, exerciseName: $0.name, order: 0, targetSets: 4, targetReps: 8, targetRIR: 1, restSeconds: 120, notes: "pause")]
        } ?? [], splitDays: ["Mon", "Thu"])
        t.notes = "heavy"
        ctx.insert(t)
        return t
    }

    func fetch<T: PersistentModel>(_ type: T.Type) -> [T] { (try? ctx.fetch(FetchDescriptor<T>())) ?? [] }

    func count<T: PersistentModel>(_ type: T.Type) -> Int { fetch(type).count }

    /// Pull + push, then assert the cycle succeeded.
    func sync(sourceLocation: SourceLocation = #_sourceLocation) async {
        await service.syncNow()
        #expect(service.status == .idle, "sync status \(service.status)", sourceLocation: sourceLocation)
    }
}

extension RemoteDoc {
    /// A remote copy of a local payload, optionally edited ("another device wrote this").
    static func of(_ id: UUID, _ fields: SyncFields, updatedAtMs: Int64? = nil, _ edit: (inout SyncFields) -> Void = { _ in }) -> RemoteDoc {
        var f = fields
        if let updatedAtMs { f["updatedAt"] = updatedAtMs }
        edit(&f)
        return RemoteDoc(id: SyncMapper.idString(id), fields: f)
    }
}
