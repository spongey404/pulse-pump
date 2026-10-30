import SwiftUI
import SwiftData

/// 7c — your profile: like 6b, but yours. EDIT, SHARE, your friends (the only place a friend can be
/// removed), your fans (people who follow you that you haven't followed back) and FIND FRIENDS.
struct YourProfileView: View {
    @Environment(\.weightUnit) private var unit
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    private var localUser: User? { users.first }

    @State private var page: ProfilePage?
    @State private var showFindFriends = false
    @State private var showEditProfile = false

    private var stats: ProfileStats { ProfileStats(posts: page?.posts ?? []) }
    private var shownName: String { viewModel.myProfile?.shownName ?? localUser?.name ?? "You" }

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: "YOU", onBack: { dismiss() }) {
                if localUser != nil {
                    Button { showEditProfile = true } label: {
                        Text("EDIT").font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.accentInk)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        Avatar(initial: shownName, size: 60)
                        VStack(alignment: .leading, spacing: 3) {
                            if !viewModel.myHandle.isEmpty {
                                Text("@\(viewModel.myHandle)").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            }
                            Text(shownName).font(.archivo(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                            Text("\(viewModel.friendCount) FRIENDS · \(viewModel.fanCount) FANS")
                                .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        if !viewModel.myHandle.isEmpty {
                            ShareLink(item: "Train with me on Ore. Find me by my handle: @\(viewModel.myHandle)") {
                                Text("SHARE").font(Font.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                    .padding(.horizontal, 14).frame(minHeight: 36)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.top, 16).padding(.bottom, 14)

                    HStack(spacing: 6) {
                        KPIBlock(label: "Streak", value: "\(viewModel.myProfile?.currentStreak ?? 0)D").frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "This Wk", value: "\(stats.trainedDaysThisWeek)").frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "Volume · 30D", value: unit.compactVolume(stats.volumeKg30d)).frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "PRs · 30D", value: "\(stats.prs30d)", valueColor: .prGold)
                            .shadow(color: Color.prGold.opacity(0.4), radius: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 14)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    if !stats.muscleSets30d.isEmpty {
                        HStack(alignment: .top, spacing: 16) {
                            BodyHeat(intensities: BodyHeat.Intensities(muscleSets: stats.muscleSets30d))
                                .frame(width: 75, height: 120)
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(MuscleSetsFormat.top(stats.muscleSets30d, count: 6, abbreviated: false), id: \.label) { m in
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
                    }

                    SectionLabel(title: "Friends", meta: "\(viewModel.friends.count)").padding(.top, 18).padding(.bottom, 6)
                    if viewModel.friends.isEmpty {
                        Text("NO FRIENDS YET · FRIENDS ARE PEOPLE YOU FOLLOW WHO FOLLOW YOU BACK")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).frame(minHeight: 44, alignment: .leading)
                    }
                    ForEach(viewModel.friends) { friend in
                        personRow(friend, detail: "\(friend.totalWorkouts) WORKOUTS") {
                            SocialPill(title: "UNFOLLOW", style: .outlined) { Task { await viewModel.unfollow(friend.uid) } }
                        }
                    }

                    if !viewModel.fans.isEmpty {
                        SectionLabel(title: "Fans", meta: "\(viewModel.fans.count)").padding(.top, 22).padding(.bottom, 6)
                        ForEach(viewModel.fans) { fan in
                            personRow(fan, detail: "FOLLOWS YOU") {
                                SocialPill(title: "FOLLOW BACK", style: .filled) { Task { await viewModel.follow(fan.uid) } }
                            }
                        }
                    }

                    if !viewModel.followingOnly.isEmpty {
                        SectionLabel(title: "Waiting For Follow Back", meta: "\(viewModel.followingOnly.count)").padding(.top, 22).padding(.bottom, 6)
                        ForEach(viewModel.followingOnly) { person in
                            personRow(person, detail: "YOU FOLLOW THEM") {
                                SocialPill(title: "UNFOLLOW", style: .outlined) { Task { await viewModel.unfollow(person.uid) } }
                            }
                        }
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
            await viewModel.loadMyProfile()
            await viewModel.loadGraph()
            if let uid = viewModel.currentUid { page = await viewModel.loadProfilePage(uid: uid) }
        }
    }

    private func personRow<Trailing: View>(_ person: FirestoreUserProfile, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                FriendProfileView(uid: person.uid, handle: person.username, name: person.shownName, viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    Avatar(initial: person.shownName, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(person.shownName).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                            if !person.username.isEmpty {
                                Text("@\(person.username)").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
                            }
                        }
                        Text(detail).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
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
}
