import SwiftUI
import SwiftData

/// Gate: unknown -> splash, signed out -> sign-in, signed in -> (wipe / onboarding / restoring / app).
/// The routing decision itself is the pure `RootGate.route` (unit tested).
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var users: [User]
    #if DEBUG
    /// `-createDevData` rebuilds the store once the app is on the main route. Until that has finished the main
    /// shell stays on the splash, so no view holds a User/Split that the reset is about to delete.
    @State private var devDataReady = DevDataConfig.fromLaunchArguments() == nil
    #endif

    @State private var signupHolder = SignupHolder()

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
            case .signIn, .onboarding:
                // One continuous console: sign-in choices, the questions, setup and the welcome. The same view stays
                // up while the account is created, so the route changing under it doesn't restart anything.
                SignupConsoleView(model: signupHolder.model(session: session, remote: gate.remote, onCreated: { gate.accountCreated(uid: $0) }))
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
                #if DEBUG
                if devDataReady { ContentView() } else { SplashView() }
                #else
                ContentView()
                #endif
            }
        }
        .environment(session)
        .onChange(of: route) { _, new in if new == .main { signupHolder.reset() } }   // a later sign-out starts a fresh console
        .environment(\.weightUnit, weightUnit)
        .onAppear { UnitPreference.current = weightUnit }
        #if DEBUG
        .task(id: session.state) { await DevDataAutoAccount.signIn(session: session) }
        .task(id: route == .onboarding) {
            guard route == .onboarding else { return }
            await DevDataAutoAccount.onboard(session: session, gate: gate, modelContext: modelContext)
        }
        #endif
        .task(id: reconcileKey) { await gate.reconcile(hasLocalUser: hasLocalUser) }
        .onChange(of: session.user?.uid, initial: true) { _, uid in AccentStore.shared.setAccount(uid) }   // each account keeps its own accent and recent row
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
            devDataReady = true
            #endif
            // One-time repair: a split picked before schedules existed gets its default days.
            SplitSchedule.repairMissingDays(modelContext: modelContext)
            WidgetDataService.updateWidgetData(modelContext: modelContext)
            // The Supernova paywall comes first for someone who just signed up; ContentView asks once it has closed.
            if !SupernovaPaywallGate.shouldShowNow() { _ = await NotificationService.shared.requestPermission() }
            await NotificationService.shared.reschedule(split: user?.selectedSplit)
        }
    }
}
