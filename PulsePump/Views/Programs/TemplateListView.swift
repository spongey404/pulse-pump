import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @State private var showCreateTemplate = false
    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        List {
            ForEach(templates) { template in
                NavigationLink(value: template) {
                    TemplateRowView(template: template)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(template)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        onStartWorkout(template)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(Color.pumpPrimary)
                }
            }
        }
        .navigationTitle("Templates")
        .navigationDestination(for: WorkoutTemplate.self) { template in
            TemplateDetailView(template: template, onStartWorkout: onStartWorkout)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateTemplate) {
            CreateTemplateView()
        }
        .onAppear {
            TemplateSeedService.seedIfNeeded(modelContext: modelContext)
        }
    }
}

struct TemplateRowView: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.body.weight(.medium))

            Text("\(template.templateExercises.count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
