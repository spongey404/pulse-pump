import SwiftUI
import SwiftData

struct SocialTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Feed").tag(0)
                Text("Friends").tag(1)
                Text("Challenges").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch selectedTab {
            case 0:
                ActivityFeedView()
            case 1:
                FriendsListView()
            default:
                ChallengesView()
            }
        }
        .navigationTitle("Social")
    }
}
