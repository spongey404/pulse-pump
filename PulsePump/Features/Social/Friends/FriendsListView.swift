import SwiftUI
import Contacts

/// 6a — Add friends: search, incoming requests, suggested (from contacts), invite link.
struct FriendsListView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var searchText = ""
    @State private var showContactsPicker = false
    @State private var contactsLoaded = false

    /// SUGGESTED shows live search results while typing, contact matches otherwise.
    private var suggested: [FirestoreUserProfile] { searchText.isEmpty ? viewModel.contactMatches : viewModel.searchResults }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Color.inkMuted)
                    TextField("Search by name or handle", text: $searchText)
                        .font(.archivo(15))
                }
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleStrong).frame(height: 1) }
                .padding(.top, 14)

                if !viewModel.pendingRequests.isEmpty {
                    SectionLabel(title: "Requests", meta: "\(viewModel.pendingRequests.count) Waiting").padding(.top, 22).padding(.bottom, 6)
                    ForEach(viewModel.pendingRequests, id: \.docId) { request in
                        requestRow(request)
                    }
                }

                SectionLabel(title: "Suggested").padding(.top, 22).padding(.bottom, 6)
                if suggested.isEmpty && !contactsLoaded {
                    Button { showContactsPicker = true } label: {
                        Text("FIND FROM CONTACTS").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.accentInk)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(suggested) { user in
                        suggestedRow(user)
                    }
                }

                SectionLabel(title: "Not On Pump").padding(.top, 22).padding(.bottom, 8)
                if let url = URL(string: "https://pulsepump.app/invite?ref=\(viewModel.currentUid ?? "")") {
                    ShareLink(item: url) {
                        DashedAdd(title: "Share Invite Link", action: {})
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.canvasBg)
        .onChange(of: searchText) { _, newValue in
            Task { await viewModel.searchUsers(query: newValue) }
        }
        .task { await viewModel.loadFriends() }
        .sheet(isPresented: $showContactsPicker) {
            ContactsPermissionView { loadContacts() }
        }
    }

    private func requestRow(_ request: (docId: String, friendship: FriendshipDoc, profile: FirestoreUserProfile?)) -> some View {
        HStack(spacing: 12) {
            Avatar(initial: request.profile?.displayName ?? "?", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.profile?.displayName ?? "Unknown").font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                Text("@\(request.profile?.username ?? "")").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button { Task { await viewModel.acceptFriendRequest(docId: request.docId) } } label: {
                Text("ACCEPT").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color.pumpAccent).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            Button { Task { await viewModel.removeFriend(docId: request.docId) } } label: {
                Text("IGNORE").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func suggestedRow(_ user: FirestoreUserProfile) -> some View {
        HStack(spacing: 12) {
            Avatar(initial: user.displayName, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                Text("@\(user.username)").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button { Task { await viewModel.sendFriendRequest(to: user.uid) } } label: {
                Text("FOLLOW").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color.pumpAccent).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func loadContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { return }
            let request = CNContactFetchRequest(keysToFetch: [CNContactEmailAddressesKey as CNKeyDescriptor])
            var emails: [String] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                for email in contact.emailAddresses { emails.append(email.value as String) }
            }
            Task { @MainActor in
                contactsLoaded = true
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
                .font(.archivo(15))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)

            Button("Allow Access") {
                onGrant()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentInk)

            Button("Not Now") { dismiss() }
                .foregroundStyle(Color.inkMuted)
        }
        .padding(32)
    }
}
