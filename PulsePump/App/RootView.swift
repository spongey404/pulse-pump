import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !users.isEmpty { WidgetDataService.updateWidgetData(modelContext: modelContext) }
        }
        .task {
            #if DEBUG
            DevDataService.runIfRequested(modelContext: modelContext)   // -createDevData 1
            #endif
            // One-time repair: a split picked before schedules existed gets its default days.
            SplitSchedule.repairMissingDays(modelContext: modelContext)
            WidgetDataService.updateWidgetData(modelContext: modelContext)
            _ = await NotificationService.shared.requestPermission()
            await NotificationService.shared.reschedule(split: user?.selectedSplit)
        }
    }
}
