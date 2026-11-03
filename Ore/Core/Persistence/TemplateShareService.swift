import Foundation
import SwiftData

/// Share-via-link for workout templates: `ore://template?data=<base64 JSON>` (links from before the rebrand, `pulsepump://…`, still open).
///
/// The payload carries everything a template is made of (name, notes, per-exercise sets / reps / RIR /
/// rest / notes, in order) but not exercise ids, which are local to a device: on import each exercise
/// is matched to the catalogue by name, and an unknown name becomes a custom exercise.
enum TemplateShareService {

    struct Payload: Codable, Equatable {
        struct Item: Codable, Equatable {
            var name: String
            var sets: Int
            var reps: Int?
            var rir: Int?
            var rest: Int?
            var notes: String?
        }
        var name: String
        var notes: String?
        var exercises: [Item]
    }

    // MARK: Export

    static func payload(for template: WorkoutTemplate) -> Payload {
        Payload(
            name: template.name,
            notes: template.notes.isEmpty ? nil : template.notes,
            exercises: template.templateExercises.sorted { $0.order < $1.order }.map {
                Payload.Item(name: $0.exerciseName, sets: $0.targetSets, reps: $0.targetReps,
                             rir: $0.targetRIR, rest: $0.restSeconds, notes: $0.notes)
            }
        )
    }

    static func shareURLString(for template: WorkoutTemplate) -> String {
        guard let data = try? JSONEncoder().encode(payload(for: template)),
              let encoded = data.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            return "\(Brand.urlScheme)://template"
        }
        return "\(Brand.urlScheme)://template?data=\(encoded)"
    }

    // MARK: Import

    /// The payload in `data` (the decoded `data` query value), or nil when it is not a template.
    static func decode(_ data: Data) -> Payload? {
        guard let p = try? JSONDecoder().decode(Payload.self, from: data),
              !p.name.trimmingCharacters(in: .whitespaces).isEmpty, !p.exercises.isEmpty else { return nil }
        return p
    }

    /// Decodes the base64 string from a link's `data` query item (tolerating URL-safe base64 and missing padding).
    static func decode(base64 raw: String) -> Payload? {
        var s = raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let data = Data(base64Encoded: s) else { return nil }
        return decode(data)
    }

    /// Creates a new template from a payload. Exercises are linked to the catalogue by name.
    @discardableResult
    static func importTemplate(_ payload: Payload, modelContext: ModelContext) -> WorkoutTemplate {
        var index = DataImportService.CatalogueIndex(modelContext: modelContext)
        var unmatched = DataImportService.ImportResult()
        let exercises = payload.exercises.enumerated().map { i, item -> TemplateExercise in
            let exercise = index.exerciseOrCreate(named: item.name, result: &unmatched)
            return TemplateExercise(
                exerciseId: exercise.id, exerciseName: exercise.name, order: i,
                targetSets: max(1, item.sets), targetReps: item.reps, targetRIR: item.rir,
                restSeconds: item.rest, notes: item.notes
            )
        }
        let template = WorkoutTemplate(name: payload.name.trimmingCharacters(in: .whitespaces), templateExercises: exercises)
        template.notes = payload.notes ?? ""
        modelContext.insert(template)
        try? modelContext.save()
        return template
    }
}
