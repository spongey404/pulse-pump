import SwiftUI
import SwiftData
import FirebaseAuth

// Groups templates with the same splitDays into one program row
struct ProgramGroup: Identifiable {
    let id: String
    let name: String
    let templates: [WorkoutTemplate]
    let splitDays: [String]

    var totalExercises: Int { templates.flatMap(\.templateExercises).count }
    var daysPerWeek: Int { splitDays.isEmpty ? max(1, templates.count) : splitDays.count }
    var lastUsedDate: Date? { templates.flatMap(\.workouts).map(\.date).max() }

    var lastUsedText: String {
        guard let date = lastUsedDate else { return "NEVER" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}

// Wraps navigation context for TemplateDetailView (single day or full multi-day group)
struct TemplateNavItem: Identifiable, Hashable {
    let id: UUID
    let templates: [WorkoutTemplate]
    let groupName: String?

    init(_ template: WorkoutTemplate, groupName: String? = nil, siblings: [WorkoutTemplate] = []) {
        self.id = template.id
        self.templates = siblings.isEmpty ? [template] : siblings
        self.groupName = groupName
    }

    init(group: ProgramGroup) {
        self.id = group.templates.first?.id ?? UUID()
        self.templates = group.templates
        self.groupName = group.name
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
