import SwiftUI
import SwiftData

struct RootView: View {
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
            // Request notification permission on first meaningful launch
            _ = await NotificationService.shared.requestPermission()
            // Reschedule reminders based on current split and preferences
            await NotificationService.shared.reschedule(split: user?.selectedSplit)
        }
    }
}
