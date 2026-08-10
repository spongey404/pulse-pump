import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    private var user: User? { users.first }

    var body: some View {
        Group {
            if users.isEmpty {
                OnboardingContainerView()
            } else {
                ContentView()
            }
        }
        .task {
            WorkoutDemoDataService.seedIfNeeded(modelContext: modelContext)
            _ = await NotificationService.shared.requestPermission()
            await NotificationService.shared.reschedule(split: user?.selectedSplit)
        }
    }
}
