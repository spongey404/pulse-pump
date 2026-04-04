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

    var body: some Scene {
        WindowGroup {
            RootView()
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
            NotificationCenter.default.post(name: .startWorkoutFromWidget, object: nil)
        default:
            break
        }
    }
}

extension Notification.Name {
    static let startWorkoutFromWidget = Notification.Name("startWorkoutFromWidget")
}
