import SwiftUI
import Contacts

struct FriendsListView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var searchText = ""
    @State private var showInviteSheet = false
    @State private var showContactsPicker = false
    @State private var contactEmails: [String] = []

    var body: some View {
        List {
            // Actions row
            Section {
                Button {
                    showContactsPicker = true
                } label: {
                    Label("Find from Contacts", systemImage: "person.crop.rectangle.stack")
                }

                Button {
                    showInviteSheet = true
                } label: {
                    Label("Invite Friends", systemImage: "link")
                }
                .sheet(isPresented: $showInviteSheet) {
                    if let url = URL(string: "https://pulsepump.app/invite?ref=\(viewModel.currentUid ?? "")") {
                        ShareLink(item: url) {
                            Text("Share Invite Link")
                        }
                        .presentationDetents([.medium])
                    }
                }
            }

            // Contact matches
            if !contactEmails.isEmpty {
                Section("From Contacts") {
                    ForEach(viewModel.contactMatches) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.mono(16, weight: .medium))
                                Text("@\(user.username)")
                                    .font(.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                Task { await viewModel.sendFriendRequest(to: user.uid) }
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.accentInk)
                            .controlSize(.small)
                        }
                    }
                }
            }

            // Pending requests
            if !viewModel.pendingRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(viewModel.pendingRequests, id: \.docId) { request in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(request.profile?.displayName ?? "Unknown")
                                    .font(.mono(16, weight: .medium))
                                Text("@\(request.profile?.username ?? "")")
                                    .font(.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Accept") {
                                Task { await viewModel.acceptFriendRequest(docId: request.docId) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentInk)
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
                                    .font(.mono(16, weight: .medium))
                                Text("@\(user.username)")
                                    .font(.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                Task { await viewModel.sendFriendRequest(to: user.uid) }
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.accentInk)
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
                                .fill(Color.inkFaint)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.mono(11))
                                        .foregroundStyle(.secondary)
                                )
                            VStack(alignment: .leading) {
                                Text(friend.displayName)
                                    .font(.mono(16, weight: .medium))
                                Text("@\(friend.username)")
                                    .font(.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(friend.totalWorkouts)")
                                    .font(.mono(11, weight: .medium))
                                Text("workouts")
                                    .font(.mono(9))
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
        .sheet(isPresented: $showContactsPicker) {
            ContactsPermissionView {
                loadContacts()
            }
        }
    }

    private func loadContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { return }
            let request = CNContactFetchRequest(keysToFetch: [CNContactEmailAddressesKey as CNKeyDescriptor])
            var emails: [String] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                for email in contact.emailAddresses {
                    emails.append(email.value as String)
                }
            }
            Task { @MainActor in
                contactEmails = emails
                await viewModel.findFriendsFromContacts(emails: emails)
            }
        }
    }
}

struct ContactsPermissionView: View {
    let onGrant: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.display(34))
                .foregroundStyle(Color.accentInk)

            Text("Find Friends from Contacts")
                .font(.display(20))

            Text("We'll check if any of your contacts are already on Pump. We only use email addresses and never store your contacts.")
                .font(.mono(16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Allow Access") {
                onGrant()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentInk)

            Button("Not Now") { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}
