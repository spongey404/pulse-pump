import SwiftUI
import SwiftData
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge count when app is opened
        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
    }
}

@main
struct OreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    let sharedModelContainer: ModelContainer
    @State private var session: AuthSession
    @State private var gate: AccountGate
    @State private var syncLifecycle: SyncServiceLifecycle

    init() {
        // Firebase must be configured (and pointed at the emulator, if requested) before any Auth/Firestore access.
        FirebaseBootstrap.configure()
        RemoteSettings.start()   // trial length, StarField tuning: Firebase Remote Config, applied without a release
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil { SupernovaService.startAppMonitor() }   // entitlements stay current app-wide
        #if DEBUG
        DevDataAutoAccount.resetStaleSession()   // -debugFreshSession: UI tests start from a clean login + store
        #endif
        let container = Self.makeModelContainer()
        sharedModelContainer = container

        let lifecycle = SyncServiceLifecycle(container: container)
        _syncLifecycle = State(initialValue: lifecycle)
        let session = AuthSession(provider: FirebaseAuthProvider(), lifecycle: lifecycle)
        session.start()
        _session = State(initialValue: session)
        _gate = State(initialValue: AccountGate(session: session, remote: FirestoreProfileRemote(),
                                                lifecycle: lifecycle, restoreGate: lifecycle))
    }

    private static func makeModelContainer() -> ModelContainer {
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
            // A store that won't open (a failed migration) must not brick the app: move it aside, never delete it, and start
            // fresh (the synced data comes back on sign-in). If even that fails, run from memory so the app still opens.
            let moved = quarantineStore(at: modelConfiguration.url)
            if moved, let fresh = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]) {
                return fresh
            }
            if let memory = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]) {
                return memory
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// Moves the store's files into `StoreBackup-<time>` beside it. True if the store file is no longer where it was.
    private static func quarantineStore(at url: URL) -> Bool {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent().appendingPathComponent("StoreBackup-\(Int(Date().timeIntervalSince1970))")
        guard (try? fm.createDirectory(at: dir, withIntermediateDirectories: true)) != nil else { return false }
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: url.path + suffix)
            if fm.fileExists(atPath: src.path) { try? fm.moveItem(at: src, to: dir.appendingPathComponent(src.lastPathComponent)) }
        }
        return !fm.fileExists(atPath: url.path)
    }

    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    private var preferredColorScheme: ColorScheme? {
        AppTheme(rawValue: appTheme)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                // `-debugGallery <section id or all>` shows the widget gallery on launch (no onboarding needed).
                if let g = UserDefaults.standard.string(forKey: "debugGallery") {
                    WidgetGalleryView(section: g == "all" ? nil : g)
                } else if let s = UserDefaults.standard.string(forKey: "debugSupernova") {
                    // `-debugSupernova paywall` shows the paywall on launch, for visual checks.
                    SupernovaDebugScreen(screen: s)
                } else { RootView(session: session, gate: gate, syncLifecycle: syncLifecycle) }
                #else
                RootView(session: session, gate: gate, syncLifecycle: syncLifecycle)
                #endif
            }
                .preferredColorScheme(preferredColorScheme)
                .onOpenURL { url in
                    if Brand.isOwnScheme(url.scheme) {
                        handleDeepLink(url)
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        guard Brand.isOwnScheme(url.scheme) else { return }
        switch url.host {
        case "start-workout":
            let template = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "template" })?.value
            NotificationCenter.default.post(name: .startWorkoutFromWidget, object: template)
        case let host where Brand.membershipLinkHosts.contains(host ?? ""):
            // Locked-widget "UNLOCK WITH SUPERNOVA" — jump to More › Supernova. (`pulse-plus` is the old spelling.)
            NotificationCenter.default.post(name: .openSupernova, object: nil)
        case "template":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value {
                // Handled by ContentView (needs the model context and an alert).
                NotificationCenter.default.post(name: .importTemplate, object: dataParam)
            }
        default:
            break
        }
    }
}

extension Notification.Name {
    static let startWorkoutFromWidget = Notification.Name("startWorkoutFromWidget")
    static let importTemplate = Notification.Name("importTemplate")
    static let openSupernova = Notification.Name("openSupernova")
}
