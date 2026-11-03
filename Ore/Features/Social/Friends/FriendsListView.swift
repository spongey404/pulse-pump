import SwiftUI

/// 5c — Add friends: search by handle, requests first (people who follow you; ACCEPT follows back and you become friends, IGNORE
/// dismisses the request), then an invite link. Suggestions with mutual friends are not shown: the app has no source for them
/// (a user's friend list is private, and there is no contacts import).
struct FriendsListView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var openedPerson: FirestoreUserProfile?
    @State private var showPerson = false
    @Environment(\.dismiss) private var dismiss

    private var typedHandle: String { HandleRules.normalize(searchText) }

    var body: some View {
        VStack(spacing: 0) {
            SocialProfileHeader(overline: "SOCIAL", title: "ADD FRIENDS", onBack: { dismiss() }) { EmptyView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        TextField("", text: $searchText, prompt: Text("Search by @username").foregroundStyle(Color.inkMuted))
                            .font(.archivo(15))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.surf2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 16).padding(.top, 14)

                    if !searchText.isEmpty {
                        SocialSectionLabel(title: "RESULTS")
                        if !HandleRules.isValid(typedHandle) {
                            hint("TYPE THE FULL HANDLE · 3 TO 20 LETTERS, NUMBERS, . OR _")
                        } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                            SkeletonRows(count: 1, rowHeight: 60).padding(.horizontal, 16)
                        } else if viewModel.searchResults.isEmpty {
                            hint("NO ONE WITH THE HANDLE @\(typedHandle.uppercased())")
                        } else {
                            ForEach(viewModel.searchResults, id: \.uid) { found in
                                resultRow(found)
                            }
                        }
                    }

                    if !viewModel.fanRequests.isEmpty {
                        SocialSectionLabel(title: "REQUESTS", meta: "\(viewModel.fanRequests.count)")
                        ForEach(viewModel.fanRequests) { fan in
                            requestRow(fan)
                        }
                    }

                    SocialSectionLabel(title: "NOT ON ORE")
                    if !viewModel.myHandle.isEmpty {
                        ShareLink(item: "Train with me on Ore. Find me by my handle: @\(viewModel.myHandle)") {
                            SocialDashedLabel(title: "SHARE INVITE LINK")
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        Text("FRIENDS FIND YOU BY TYPING YOUR EXACT HANDLE · @\(viewModel.myHandle.uppercased())")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showPerson) {
            if let p = openedPerson {
                FriendProfileView(uid: p.uid, handle: p.username, name: p.shownName, viewModel: viewModel)
            }
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
        Text(text).font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 16).frame(minHeight: 44, alignment: .leading)
    }

    private func personRow<Trailing: View>(_ person: FirestoreUserProfile, @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        PersonListRow(
            name: person.shownName,
            description: person.username.isEmpty ? nil : "@\(person.username)",
            accentHex: FriendMembership.accentHex(forUid: person.uid),
            onTap: { openedPerson = person; showPerson = true },
            actions: trailing
        )
    }

    private func requestRow(_ fan: FirestoreUserProfile) -> some View {
        personRow(fan) {
            SocialSmallButton(title: "IGNORE", style: .outlined) { viewModel.ignore(fan.uid) }
            SocialSmallButton(title: "ACCEPT", style: .filled) { Task { await viewModel.accept(fan.uid) } }
        }
    }

    private func resultRow(_ found: UserLookup) -> some View {
        let person = found.profile ?? .restricted(uid: found.uid, handle: found.handle)
        let relation = viewModel.relationship(with: found.uid)
        return personRow(person) {
            switch relation {
            case .friends:
                SocialSmallButton(title: "FRIENDS", style: .outlined, isStatic: true) {}
            case .following:
                SocialSmallButton(title: "FOLLOWING", style: .outlined, isStatic: true) {}
            case .fan:
                SocialSmallButton(title: "FOLLOW BACK", style: .filled) { Task { await viewModel.follow(found.uid) } }
            default:
                SocialSmallButton(title: "FOLLOW", style: .outlined) { Task { await viewModel.follow(found.uid) } }
            }
        }
    }
}
