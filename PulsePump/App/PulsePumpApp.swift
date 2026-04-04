import SwiftUI
import SwiftData

@main
struct PulsePumpApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Exercise.self,
            WorkoutTemplate.self,
            Workout.self,
            ExerciseLog.self,
            SetLog.self,
            Split.self,
            EquipmentProfile.self,
            UserProfile.self,
            Challenge.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
