import SwiftUI
import SwiftData

/// Gate: unknown -> splash, signed out -> sign-in, signed in -> (wipe / onboarding / restoring / app).
/// The routing decision itself is the pure `RootGate.route` (unit tested).
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var users: [User]

    let session: AuthSession
    let gate: AccountGate
    let syncLifecycle: SyncServiceLifecycle

    private var user: User? { users.first }
    private var hasLocalUser: Bool { !users.isEmpty }
    /// Single source for the display unit; views read `@Environment(\.weightUnit)`.
    private var weightUnit: UnitPreference { user?.unitPreference ?? .kg }
    private var route: RootRoute { gate.route(hasLocalUser: hasLocalUser) }

    /// Re-run the gate's side effects when any of these change (deliberately not the cloud status).
    private var reconcileKey: String {
        "\(session.user?.uid ?? "-")|\(hasLocalUser)|\(gate.localOwnerUid ?? "-")|\(session.isTearingDown)"
    }

    var body: some View {
        Group {
            switch route {
            case .splash, .wipeLocalStore:
                SplashView()
            case .signIn:
                SignInView(session: session)
            case .onboarding:
                OnboardingContainerView(
                    uid: session.user?.uid ?? "",
                    prefilledName: session.user?.displayName ?? "",
                    remote: gate.remote,
                    onCreated: { gate.accountCreated(uid: $0) }
                )
                .id(session.user?.uid)
            case .restoring:
                RestoringView()
                    .task { await gate.waitForRestore() }
            case .restoreFailed:
                GateMessageView(
                    title: "Couldn't restore your data",
                    message: "Your account exists but nothing came back from the cloud.",
                    primary: ("TRY AGAIN", { Task { await gate.retry(hasLocalUser: hasLocalUser) } }),
                    secondary: ("SIGN OUT", { Task { await session.signOut() } })
                )
            case .offlineRetry:
                GateMessageView(
                    title: "You're offline",
                    message: "Connect to the internet once to finish setting up this device.",
                    primary: ("TRY AGAIN", { Task { await gate.retry(hasLocalUser: hasLocalUser) } }),
                    secondary: ("SIGN OUT", { Task { await session.signOut() } })
                )
            case .main:
                ContentView()
            }
        }
        .environment(session)
        .environment(\.weightUnit, weightUnit)
        .onAppear { UnitPreference.current = weightUnit }
        .task(id: reconcileKey) { await gate.reconcile(hasLocalUser: hasLocalUser) }
        .task(id: "\(session.user?.uid ?? "-")|\(route == .main || route == .restoring)") {
            // Sync runs whenever a signed-in user owns the local store; the pull creates the User on a new device.
            guard let uid = session.user?.uid, route == .main || route == .restoring else { return }
            syncLifecycle.ensureRunning(uid: uid)
        }
        .onChange(of: weightUnit) { _, unit in
            UnitPreference.current = unit
            WidgetDataService.updateWidgetData(modelContext: modelContext)   // widgets label from the snapshot
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if route == .main { WidgetDataService.updateWidgetData(modelContext: modelContext) }
            if route == .offlineRetry { Task { await gate.retry(hasLocalUser: hasLocalUser) } }
        }
        .task(id: route == .main) {
            guard route == .main else { return }
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
