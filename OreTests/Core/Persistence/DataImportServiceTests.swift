import Testing
import Foundation
import SwiftData
@testable import Ore

@MainActor
struct DataImportServiceTests {
    static func setup() throws -> (ModelContext, User) {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        for e in ExerciseSeedService.allExercises { ctx.insert(e) }
        let user = User(name: "T")
        ctx.insert(user)
        return (ctx, user)
    }

    static let strong = """
    Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
    2025-03-03 18:00:00,Push A,1h 5m,Bench Press (Barbell),W,40,10,0,0,,,
    2025-03-03 18:00:00,Push A,1h 5m,Bench Press (Barbell),1,"82,5",8,0,0,,,8
    2025-03-03 18:00:00,Push A,1h 5m,Bench Press (Barbell),2,82.5,7,0,0,,,
    2025-03-03 18:00:00,Push A,1h 5m,Mystery Machine Thing,1,30,12,0,0,,,
    not-a-date,Push A,1h,Barbell Row,1,60,10,0,0,,,
    """

    // MARK: Strong

    @Test func linksByNormalisedNameAndCreatesCustomOnlyForUnknown() throws {
        let (ctx, user) = try Self.setup()
        let r = try DataImportService.importStrongCSV(Self.strong, modelContext: ctx, user: user)

        #expect(r.imported == 1)
        #expect(r.importedSets == 4)
        #expect(r.unmatchedExercises == ["Mystery Machine Thing"])
        let customs = try ctx.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
        #expect(customs.map(\.name) == ["Mystery Machine Thing"])

        let w = try #require(try ctx.fetch(FetchDescriptor<Workout>()).first)
        let bench = try #require(w.exerciseLogs.first { $0.exercise?.name == "Barbell Bench Press" })   // "(Barbell)" suffix mapped
        #expect(bench.sets.count == 3)
    }

    @Test func badDatesAreErrorRowsNotNow() throws {
        let (ctx, user) = try Self.setup()
        let r = try DataImportService.importStrongCSV(Self.strong, modelContext: ctx, user: user)
        #expect(r.skippedRows == 1)
        #expect(r.errors.first?.contains("unreadable date 'not-a-date'") == true)
        // Nothing was dated "now".
        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        #expect(workouts.allSatisfy { $0.date < Date().addingTimeInterval(-86_400 * 30) })
    }

    @Test func warmupsAreKeptButMarked() throws {
        let (ctx, user) = try Self.setup()
        let r = try DataImportService.importStrongCSV(Self.strong, modelContext: ctx, user: user)
        #expect(r.warmupSets == 1)
        let w = try #require(try ctx.fetch(FetchDescriptor<Workout>()).first)
        #expect(w.workingSetCount == 3)                     // 4 saved, warm-up not counted
        #expect(w.exerciseLogs.flatMap(\.sets).count == 4)
    }

    @Test func decimalCommaWeightsParse() throws {
        let (ctx, user) = try Self.setup()
        try DataImportService.importStrongCSV(Self.strong, modelContext: ctx, user: user)
        let weights = try ctx.fetch(FetchDescriptor<SetLog>()).map(\.weight)
        #expect(weights.contains(82.5))
    }

    @Test func reimportingTheSameFileIsANoOp() throws {
        let (ctx, user) = try Self.setup()
        let first = try DataImportService.importStrongCSV(Self.strong, modelContext: ctx, user: user)
        let second = try DataImportService.importStrongCSV(Self.strong, modelContext: ctx, user: user)
        #expect(first.imported == 1)
        #expect(second.imported == 0 && second.importedSets == 0)
        #expect(second.duplicateWorkouts == 1 && second.duplicateSets == 4)
        #expect(try ctx.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(try ctx.fetchCount(FetchDescriptor<SetLog>()) == 4)
        #expect(try ctx.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom })) == 1)   // not duplicated either
    }

    @Test func twoWorkoutsSharingADateStayDistinct() throws {
        let (ctx, user) = try Self.setup()
        let csv = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Reps
        2025-03-03 18:00:00,Push A,Barbell Bench Press,1,80,5
        2025-03-03 18:00:00,Pull A,Barbell Row,1,70,5
        """
        let r = try DataImportService.importStrongCSV(csv, modelContext: ctx, user: user)
        #expect(r.imported == 2)
    }

    // MARK: Hevy

    @Test func hevyImportMapsSetTypesAndDatesAndReportsCounts() throws {
        let (ctx, user) = try Self.setup()
        let csv = """
        title,start_time,end_time,description,exercise_title,superset_id,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe
        Pull,"3 Mar 2025, 18:00","3 Mar 2025, 19:00",,Barbell Row,,0,warmup,40,10,,,
        Pull,"3 Mar 2025, 18:00","3 Mar 2025, 19:00",,Barbell Row,,1,normal,"72,5",8,,,9
        Pull,garbage,,,Barbell Row,,2,normal,72.5,8,,,
        """
        let r = try DataImportService.importHevyCSV(csv, modelContext: ctx, user: user)
        #expect(r.imported == 1 && r.importedSets == 2 && r.skippedRows == 1 && r.warmupSets == 1)
        #expect(r.unmatchedExercises.isEmpty)
        let w = try #require(try ctx.fetch(FetchDescriptor<Workout>()).first)
        #expect(w.duration == 3600)
        let sets = w.exerciseLogs[0].sets.sorted { $0.order < $1.order }
        #expect(sets[0].setType == .warmup && sets[1].setType == .standard)
        #expect(sets[1].weight == 72.5 && sets[1].rir == 1)
        #expect(r.summary.contains("Imported 1 workout"))
    }

    // MARK: Parser

    @Test func csvParserHandlesQuotesCommasAndNewlines() {
        let rows = DataImportService.parseCSV("a,b,c\r\n1,\"x, y\",\"line1\nline2\"\n2,\"say \"\"hi\"\"\",z\n")
        #expect(rows.count == 3)
        #expect(rows[1] == ["1", "x, y", "line1\nline2"])
        #expect(rows[2] == ["2", "say \"hi\"", "z"])
    }

    @Test func nameNormalisationAndCandidateKeys() {
        #expect(Exercise.normalisedName("Barbell Bench-Press") == Exercise.normalisedName("barbell  bench press"))
        #expect(DataImportService.candidateKeys(for: "Squat (Barbell)").contains("barbell squat"))
        #expect(DataImportService.candidateKeys(for: "Pull Up").count == 1)
    }
}
