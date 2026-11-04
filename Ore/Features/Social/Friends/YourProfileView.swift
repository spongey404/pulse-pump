import SwiftUI
import SwiftData

/// 5b — your profile: EDIT and SHARE up top, four figures, and the list of people you FOLLOW with UNFOLLOW on each row
/// (the only place to unfollow someone). Requests from people who follow you are answered in Add friends.
struct YourProfileView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    private var localUser: User? { users.first }

    @State private var showFindFriends = false
    @State private var showEditProfile = false
    @State private var openedPerson: FirestoreUserProfile?
    @State private var showPerson = false

    private var shownName: String { viewModel.myProfile?.shownName ?? localUser?.name ?? "You" }
    private var isMember: Bool { AccentStore.shared.isMember }

    /// Everyone I follow: my friends (they follow back) and the people who haven't yet.
    private var following: [FirestoreUserProfile] {
        (viewModel.friends + viewModel.followingOnly)
            .sorted { $0.shownName.localizedCaseInsensitiveCompare($1.shownName) == .orderedAscending }
    }
    private var followersCount: Int { viewModel.friends.count + viewModel.fans.count }

    var body: some View {
        VStack(spacing: 0) {
            SocialProfileHeader(overline: viewModel.myHandle.isEmpty ? "" : "@\(viewModel.myHandle)", title: "YOU", onBack: { dismiss() }) {
                if localUser != nil {
                    Button { showEditProfile = true } label: { HeaderSquareLabel(text: "EDIT") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit profile")
                }
            }
            .textCase(.uppercase)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        PersonTile(name: shownName, size: 64, isMe: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shownName).font(.archivo(26, weight: .black)).foregroundStyle(Color.inkPrimary)
                                .lineLimit(1).minimumScaleFactor(0.6)
                            if isMember { SupernovaTag() }
                        }
                        Spacer(minLength: 0)
                        if !viewModel.myHandle.isEmpty {
                            ShareLink(item: "Train with me on Ore. Find me by my handle: @\(viewModel.myHandle)") {
                                Text("SHARE").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                                    .padding(.horizontal, 12).frame(height: 32)
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                            }
                            .accessibilityIdentifier(AX.social.pill("SHARE"))
                        }
                    }
                    .padding(16)

                    HStack(spacing: 6) {
                        ProfileFigure(label: "STREAK", value: "\(HomeWeekStats(workouts: workouts, templates: []).weekStreak) WK")
                        ProfileFigure(label: "WORKOUTS", value: "\(viewModel.myProfile?.totalWorkouts ?? 0)")
                        ProfileFigure(label: "FOLLOWERS", value: "\(followersCount)")
                        ProfileFigure(label: "FOLLOWING", value: "\(following.count)")
                    }
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 17)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    SocialSectionLabel(title: "FOLLOWING", meta: "\(following.count)")
                    if following.isEmpty {
                        Text("NOT FOLLOWING ANYONE YET")
                            .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    ForEach(following) { person in
                        PersonListRow(
                            name: person.shownName,
                            description: LastTrained.text(for: person.uid, in: viewModel.feedItems)
                                ?? (person.username.isEmpty ? nil : "@\(person.username)"),
                            accentHex: FriendMembership.accentHex(forUid: person.uid),
                            onTap: { openedPerson = person; showPerson = true }
                        ) {
                            SocialSmallButton(title: "UNFOLLOW", style: .outlined) { Task { await viewModel.unfollow(person.uid) } }
                        }
                    }

                    Button { showFindFriends = true } label: { SocialDashedLabel(title: "+ FIND FRIENDS") }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .accessibilityLabel("Find friends")
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showPerson) {
            if let p = openedPerson {
                FriendProfileView(uid: p.uid, handle: p.username, name: p.shownName, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showFindFriends) {
            NavigationStack { FriendsListView(viewModel: viewModel) }
        }
        .sheet(isPresented: $showEditProfile) {
            if let localUser {
                NavigationStack { EditProfileView(user: localUser) }
            }
        }
        .task {
            await viewModel.loadMyProfile()
            await viewModel.loadGraph()
        }
    }
}
