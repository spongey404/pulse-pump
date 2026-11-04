import SwiftUI
import SwiftData

struct SocialTabView: View {
    @State private var viewModel = SocialViewModel.shared
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft }) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            ActivityFeedView(viewModel: viewModel)
        }
        .task(id: users.first?.name) {
            SocialServices.localName = users.first?.name
            SocialServices.localHandle = users.first.map { HandleRules.sanitize($0.username.isEmpty ? $0.name : $0.username) }
            await viewModel.loadMyProfile()
            await viewModel.restorePrivacy()
        }
        .task(id: workouts.count) {
            await viewModel.syncOwnStats(streak: HomeWeekStats(workouts: workouts, templates: []).weekStreak,      // weeks, like everywhere else
                                         
                                         totalWorkouts: workouts.count)
        }
        .alert("Social", isPresented: Binding(get: { viewModel.lastError != nil }, set: { if !$0 { viewModel.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.lastError ?? "")
        }
    }
}
