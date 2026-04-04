import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var users: [User]

    var body: some View {
        if users.isEmpty {
            OnboardingContainerView()
        } else {
            ContentView()
        }
    }
}
