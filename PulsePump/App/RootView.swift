import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var users: [User]

    private var user: User? { users.first }
    /// Single source for the display unit; views read `@Environment(\.weightUnit)`.
    private var weightUnit: UnitPreference { user?.unitPreference ?? .kg }

    var body: some View {
        Group {
            if users.isEmpty {
                OnboardingContainerView()
            } else {
                ContentView()
            }
        }
        .environment(\.weightUnit, weightUnit)
        .onAppear { UnitPreference.current = weightUnit }
        .onChange(of: weightUnit) { _, unit in
            UnitPreference.current = unit
            WidgetDataService.updateWidgetData(modelContext: modelContext)   // widgets label from the snapshot
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !users.isEmpty { WidgetDataService.updateWidgetData(modelContext: modelContext) }
        }
        .task {
            #if DEBUG
            DevDataService.runIfRequested(modelContext: modelContext)   // -createDevData 1
            #endif
            WidgetDataService.updateWidgetData(modelContext: modelContext)
            _ = await NotificationService.shared.requestPermission()
            await NotificationService.shared.reschedule(split: user?.selectedSplit)
        }
    }
}
