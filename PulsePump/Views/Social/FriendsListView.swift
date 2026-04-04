import SwiftUI

struct FriendsListView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var searchText = ""

    var body: some View {
        List {
            // Pending requests
            if !viewModel.pendingRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(viewModel.pendingRequests, id: \.docId) { request in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(request.profile?.displayName ?? "Unknown")
                                    .font(.body.weight(.medium))
                                Text("@\(request.profile?.username ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Accept") {
                                Task { await viewModel.acceptFriendRequest(docId: request.docId) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.pumpPrimary)
                            .controlSize(.small)
                        }
                    }
                }
            }

            // Search results
            if !searchText.isEmpty && !viewModel.searchResults.isEmpty {
                Section("Search Results") {
                    ForEach(viewModel.searchResults) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.body.weight(.medium))
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                Task { await viewModel.sendFriendRequest(to: user.uid) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            // Friends list
            Section("Friends") {
                if viewModel.friends.isEmpty {
                    ContentUnavailableView(
                        "No Friends Yet",
                        systemImage: "person.2.slash",
                        description: Text("Search by username to add friends.")
                    )
                } else {
                    ForEach(viewModel.friends) { friend in
                        HStack {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                )
                            VStack(alignment: .leading) {
                                Text(friend.displayName)
                                    .font(.body.weight(.medium))
                                Text("@\(friend.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(friend.totalWorkouts)")
                                    .font(.caption.weight(.semibold))
                                Text("workouts")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search by username")
        .onChange(of: searchText) { _, newValue in
            Task { await viewModel.searchUsers(query: newValue) }
        }
        .task {
            await viewModel.loadFriends()
        }
    }
}
