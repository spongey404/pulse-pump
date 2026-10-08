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
struct PulsePumpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    let sharedModelContainer: ModelContainer
    @State private var session: AuthSession
    @State private var gate: AccountGate
    @State private var syncLifecycle: SyncServiceLifecycle

    init() {
        // Firebase must be configured (and pointed at the emulator, if requested) before any Auth/Firestore access.
        FirebaseBootstrap.configure()
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
            fatalError("Could not create ModelContainer: \(error)")
        }
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
                } else { RootView(session: session, gate: gate, syncLifecycle: syncLifecycle) }
                #else
                RootView(session: session, gate: gate, syncLifecycle: syncLifecycle)
                #endif
            }
                .preferredColorScheme(preferredColorScheme)
                .onOpenURL { url in
                    if url.scheme == "pulsepump" {
                        handleDeepLink(url)
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "pulsepump" else { return }
        switch url.host {
        case "start-workout":
            let template = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "template" })?.value
            NotificationCenter.default.post(name: .startWorkoutFromWidget, object: template)
        case "pulse-plus":
            // Locked-widget "UNLOCK PULSE+" — jump to More › Pulse+.
            NotificationCenter.default.post(name: .openPulsePlus, object: nil)
        case "template":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value,
               let decoded = Data(base64Encoded: dataParam) {
                NotificationCenter.default.post(name: .importTemplate, object: decoded)
            }
        default:
            break
        }
    }
}

extension Notification.Name {
    static let startWorkoutFromWidget = Notification.Name("startWorkoutFromWidget")
    static let importTemplate = Notification.Name("importTemplate")
    static let openPulsePlus = Notification.Name("openPulsePlus")
}
