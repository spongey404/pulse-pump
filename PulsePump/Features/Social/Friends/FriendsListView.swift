import SwiftUI

/// 6a — Add friends: find by handle, friend requests (fans waiting for a follow back), invite.
///
/// Friends are people who follow each other. A person who follows you but whom you don't follow is a
/// fan, and shows up here as a request: ACCEPT follows them back (you become friends), IGNORE
/// dismisses the request (they stay a fan).
struct FriendsListView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    private var typedHandle: String { HandleRules.normalize(searchText) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Color.inkMuted)
                    TextField("Find someone by their @handle", text: $searchText)
                        .font(.archivo(15))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                }
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleStrong).frame(height: 1) }
                .padding(.top, 14)

                if !searchText.isEmpty {
                    SectionLabel(title: "Results").padding(.top, 22).padding(.bottom, 6)
                    if !HandleRules.isValid(typedHandle) {
                        hint("TYPE THE FULL HANDLE · 3 TO 20 LETTERS, NUMBERS, . OR _")
                    } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                        SkeletonRows(count: 1, rowHeight: 60)
                    } else if viewModel.searchResults.isEmpty {
                        hint("NO ONE WITH THE HANDLE @\(typedHandle.uppercased())")
                    } else {
                        ForEach(viewModel.searchResults, id: \.uid) { found in
                            resultRow(found)
                        }
                    }
                }

                if !viewModel.fanRequests.isEmpty {
                    SectionLabel(title: "Friend Requests", meta: "\(viewModel.fanRequests.count) Waiting").padding(.top, 22).padding(.bottom, 6)
                    ForEach(viewModel.fanRequests) { fan in
                        requestRow(fan)
                    }
                }

                if !viewModel.followingOnly.isEmpty {
                    SectionLabel(title: "Waiting For Follow Back", meta: "\(viewModel.followingOnly.count)").padding(.top, 22).padding(.bottom, 6)
                    ForEach(viewModel.followingOnly) { person in
                        personRow(person) {
                            SocialPill(title: "UNFOLLOW", style: .outlined) { Task { await viewModel.unfollow(person.uid) } }
                        }
                    }
                }

                SectionLabel(title: "Invite").padding(.top, 22).padding(.bottom, 8)
                if !viewModel.myHandle.isEmpty {
                    ShareLink(item: "Train with me on Pump. Find me by my handle: @\(viewModel.myHandle)") {
                        DashedAdd(title: "Share Your Handle", action: {})
                            .allowsHitTesting(false)
                    }
                    Text("FRIENDS FIND YOU BY TYPING YOUR EXACT HANDLE · @\(viewModel.myHandle.uppercased())")
                        .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.canvasBg)
        .navigationTitle("Find Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        }
        .onChange(of: searchText) { _, newValue in
            // Debounce, and let the view model drop out-of-order answers.
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await viewModel.searchUsers(query: newValue)
            }
        }
        .task {
            await viewModel.loadMyProfile()
            await viewModel.loadGraph()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).frame(minHeight: 44, alignment: .leading)
    }

    private func personRow<Trailing: View>(_ person: FirestoreUserProfile, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                FriendProfileView(uid: person.uid, handle: person.username, name: person.shownName, viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    Avatar(initial: person.shownName, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.shownName).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                        if !person.username.isEmpty {
                            Text("@\(person.username)").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            trailing()
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func requestRow(_ fan: FirestoreUserProfile) -> some View {
        personRow(fan) {
            HStack(spacing: 8) {
                SocialPill(title: "ACCEPT", style: .filled) { Task { await viewModel.accept(fan.uid) } }
                SocialPill(title: "IGNORE", style: .outlined) { viewModel.ignore(fan.uid) }
            }
        }
    }

    private func resultRow(_ found: UserLookup) -> some View {
        let person = found.profile ?? .restricted(uid: found.uid, handle: found.handle)
        let relation = viewModel.relationship(with: found.uid)
        return personRow(person) {
            switch relation {
            case .friends:
                Text("FRIENDS").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted)
            case .following:
                SocialPill(title: "FOLLOWING", style: .outlined) { Task { await viewModel.unfollow(found.uid) } }
            case .fan:
                SocialPill(title: "FOLLOW BACK", style: .filled) { Task { await viewModel.follow(found.uid) } }
            default:
                SocialPill(title: "FOLLOW", style: .filled) { Task { await viewModel.follow(found.uid) } }
            }
        }
    }
}
