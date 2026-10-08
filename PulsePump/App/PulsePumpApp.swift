import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
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
                } else { RootView() }
                #else
                RootView()
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
