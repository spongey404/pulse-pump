import Testing
import Foundation
import SwiftData
@testable import PulsePump

@MainActor
struct TemplateSeedServiceTests {
    static func seededContext() throws -> ModelContext {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        for e in ExerciseSeedService.allExercises { ctx.insert(e) }
        return ctx
    }

    @Test func everyPresetExerciseNameExistsInTheCatalogue() {
        let catalogue = Set(ExerciseSeedService.allExercises.map { Exercise.normalisedName($0.name) })
        let presetNames = Set(TemplateSeedService.allTemplates.flatMap(\.templateExercises).map(\.exerciseName))
        #expect(presetNames.count == 21)
        for name in presetNames {
            #expect(catalogue.contains(Exercise.normalisedName(name)), "\(name) missing from catalogue")
        }
    }

    @Test func seedingLinksPresetsToCatalogueIdsByName() throws {
        let ctx = try Self.seededContext()
        TemplateSeedService.seedIfNeeded(modelContext: ctx)
        let templates = try ctx.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 7)
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        for te in templates.flatMap(\.templateExercises) {
            let linked = try #require(byId[te.exerciseId], "\(te.exerciseName) has a dangling id")
            #expect(linked.name == te.exerciseName)
            #expect(te.exerciseId != TemplateSeedService.unresolvedId)
        }
    }

    @Test func existingTemplatesWithRandomIdsAreRepairedOnce() throws {
        let ctx = try Self.seededContext()
        // An install seeded before the fix: random ids.
        for t in TemplateSeedService.allTemplates {
            t.templateExercises = t.templateExercises.map { var x = $0; x.exerciseId = UUID(); return x }
            ctx.insert(t)
        }
        TemplateSeedService.seedIfNeeded(modelContext: ctx)           // repairs, does not re-seed
        let templates = try ctx.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 7)
        let ids = Set(try ctx.fetch(FetchDescriptor<Exercise>()).map(\.id))
        #expect(templates.flatMap(\.templateExercises).allSatisfy { ids.contains($0.exerciseId) })
    }

    @Test func realIdsAreKeptAndUnknownNamesReported() throws {
        let ctx = try Self.seededContext()
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        let bench = try #require(exercises.first { $0.name == "Barbell Bench Press" })
        let t = WorkoutTemplate(name: "Mine", templateExercises: [
            TemplateExercise(exerciseId: bench.id, exerciseName: "Some Renamed Label", order: 0),
            TemplateExercise(exerciseId: UUID(), exerciseName: "Not A Real Lift", order: 1),
        ])
        ctx.insert(t)
        let unmatched = TemplateSeedService.resolveExerciseLinks(in: [t], exercises: exercises)
        #expect(unmatched == ["Not A Real Lift"])
        #expect(t.templateExercises[0].exerciseId == bench.id)
    }
}
