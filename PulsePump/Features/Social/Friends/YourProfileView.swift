import SwiftUI
import SwiftData
import FirebaseAuth

/// 7c — your profile: like 6b, but yours — EDIT, SHARE, and FOLLOWING with UNFOLLOW (the
/// only surface a friend can be removed from).
struct YourProfileView: View {
    @Environment(\.weightUnit) private var unit
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    private var localUser: User? { users.first }

    @State private var profile: FirestoreUserProfile?
    @State private var recentPosts: [WorkoutFeedItem] = []
    @State private var showFindFriends = false
    @State private var showEditProfile = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                Text("YOU").font(.archivo(22, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                Spacer()
                if localUser != nil {
                    Button { showEditProfile = true } label: {
                        Text("EDIT").font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.accentInk)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        Avatar(initial: profile?.displayName ?? "You", size: 60)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("@\(profile?.username ?? "yourhandle")").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            Text(profile?.displayName ?? "You").font(.archivo(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        }
                        Spacer()
                        if let uid = viewModel.currentUid, let url = URL(string: "https://pulsepump.app/u/\(uid)") {
                            ShareLink(item: url) {
                                Text("SHARE").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.top, 16).padding(.bottom, 14)

                    HStack(spacing: 6) {
                        KPIBlock(label: "Streak", value: "\(profile?.currentStreak ?? 0)D")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "This Wk", value: "\(recentPosts.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }.count)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "Volume", value: volumeLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "PRs · 30D", value: "\(recentPosts.reduce(0) { $0 + $1.prCount })", valueColor: .prGold)
                            .shadow(color: Color.prGold.opacity(0.4), radius: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 14)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    HStack(alignment: .top, spacing: 16) {
                        BodyHeat(intensities: BodyHeat.Intensities(exercises: recentPosts.flatMap(\.exercises)))
                            .frame(width: 75, height: 120)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(perMuscleSetCounts, id: \.label) { m in
                                HStack {
                                    Text(m.label).font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                    Spacer()
                                    Text("\(m.count)").font(Font.spaceMono(11, weight: .bold)).foregroundStyle(Color.inkPrimary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    SectionLabel(title: "Following", meta: "\(viewModel.friends.count)").padding(.top, 18).padding(.bottom, 6)

                    ForEach(viewModel.friends) { friend in
                        followingRow(friend)
                    }

                    SectionLabel(title: "Grow Your Circle").padding(.top, 22).padding(.bottom, 8)
                    DashedAdd(title: "Find Friends") { showFindFriends = true }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showFindFriends) {
            NavigationStack { FriendsListView(viewModel: viewModel) }
        }
        .sheet(isPresented: $showEditProfile) {
            if let localUser {
                NavigationStack { EditProfileView(user: localUser) }
            }
        }
        .task {
            if let uid = viewModel.currentUid {
                profile = try? await viewModel.firestoreService.fetchUserProfile(uid: uid)
                recentPosts = (try? await viewModel.firestoreService.fetchOwnFeed()) ?? []
            }
            await viewModel.loadFriends()
        }
    }

    private var volumeLabel: String {
        let total = recentPosts.flatMap(\.exercises).flatMap(\.sets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return unit.compactVolume(total)   // feed weights are kg
    }

    /// Same weighted derivation as `FriendProfileView` — primary muscles full credit,
    /// secondary half, via `muscleSetCounts()`.
    private var perMuscleSetCounts: [(label: String, count: Int)] {
        recentPosts.flatMap(\.exercises).muscleSetCounts()
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { ($0.key.displayName.uppercased(), Int($0.value.rounded())) }
    }

    private func followingRow(_ friend: FirestoreUserProfile) -> some View {
        HStack(spacing: 12) {
            Avatar(initial: friend.displayName, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(friend.displayName).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text("@\(friend.username)").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
                }
                Text("\(friend.totalWorkouts) WORKOUTS").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button {
                Task { await viewModel.unfollow(uid: friend.uid) }
            } label: {
                Text("UNFOLLOW").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
