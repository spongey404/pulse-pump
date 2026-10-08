import SwiftUI

/// 6b — someone else's profile, honouring their privacy and my relationship to them:
/// - visible profile: stats, 30-day body map and this week's sessions, from their *posted* sessions
///   that I'm allowed to see (a friend sees friends-only posts, anyone else only public ones);
/// - private profile (friends-only / only-me, or a block): handle and FOLLOW only;
/// - deleted account: a plain "no longer available" state.
struct FriendProfileView: View {
    @Environment(\.weightUnit) private var unit
    let uid: String
    let handle: String
    let name: String
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var page: ProfilePage?
    @State private var openedPost: WorkoutFeedItem?
    @State private var confirmUnfollow = false
    @State private var confirmBlock = false
    @State private var menuOpen = false
    @State private var message: String?

    private var relationship: Relationship { viewModel.relationship(with: uid) }
    private var profile: FirestoreUserProfile? { page?.profile }
    private var shownName: String { profile?.shownName ?? name }
    private var shownHandle: String { (profile?.username.isEmpty == false ? profile?.username : nil) ?? handle }
    private var stats: ProfileStats { ProfileStats(posts: page?.posts ?? []) }

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: "", onBack: { dismiss() }) {
                if relationship != .me && page?.access != .unavailable {
                    Button { menuOpen = true } label: {
                        Image(systemName: "ellipsis").font(.system(size: 18)).foregroundStyle(Color.inkMuted).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile options")
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identityRow

                    switch page?.access {
                    case .none:
                        SkeletonRows(count: 3).padding(.top, 20)
                    case .unavailable:
                        notice("This account is no longer available.", icon: "person.slash")
                    case .restricted:
                        if relationship == .blocked {
                            blockedNotice
                        } else {
                            notice("Private profile", detail: "Only the handle is visible. Follow @\(shownHandle) to be friends when they follow you back.", icon: "lock")
                        }
                    case .visible:
                        visibleContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task(id: relationship) { page = await viewModel.loadProfilePage(uid: uid) }
        .fullScreenCover(item: $openedPost) { post in
            FeedSessionSheet(item: post, viewModel: viewModel)
        }
        .confirmationDialog("Profile options", isPresented: $menuOpen) {
            Button("Report @\(shownHandle)", role: .destructive) {
                Task { if await viewModel.reportUser(uid) { message = "Reported. Thanks for letting us know." } }
            }
            if relationship == .blocked {
                Button("Unblock") { Task { await viewModel.unblock(uid: uid) } }
            } else {
                Button("Block @\(shownHandle)", role: .destructive) { confirmBlock = true }
            }
        }
        .confirmationDialog("Unfollow \(shownName)?", isPresented: $confirmUnfollow, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) { Task { await viewModel.unfollow(uid) } }
        } message: {
            Text(relationship == .friends ? "You'll stop being friends. They stay your fan." : "You'll stop following them.")
        }
        .alert("Block @\(shownHandle)?", isPresented: $confirmBlock) {
            Button("Block", role: .destructive) {
                Task {
                    if await viewModel.block(uid: uid, name: shownName, handle: shownHandle) { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They disappear from your feed, search and lists, and can't follow you.")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {}
        }
    }

    // MARK: Identity + relationship

    private var identityRow: some View {
        HStack(alignment: .center, spacing: 14) {
            Avatar(initial: shownName, size: 60)
            VStack(alignment: .leading, spacing: 3) {
                if !shownHandle.isEmpty {
                    Text("@\(shownHandle)").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                Text(page?.access == .restricted ? "Private profile" : shownName)
                    .font(.archivo(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                if let profile, page?.access == .visible {
                    Text("\(profile.friendCount) FRIENDS · \(profile.fanCount) FANS")
                        .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            relationshipButton
        }
        .padding(.top, 16).padding(.bottom, 14)
    }

    @ViewBuilder
    private var relationshipButton: some View {
        if page?.access == .unavailable {
            EmptyView()
        } else {
            switch relationship {
            case .me, .blocked:
                EmptyView()
            case .friends:
                SocialPill(title: "FRIENDS", style: .outlined) { confirmUnfollow = true }
            case .following:
                SocialPill(title: "FOLLOWING", style: .outlined) { confirmUnfollow = true }
            case .fan:
                SocialPill(title: "FOLLOW BACK", style: .filled) { Task { await viewModel.follow(uid) } }
            case .stranger:
                SocialPill(title: "FOLLOW", style: .filled) { Task { await viewModel.follow(uid) } }
            }
        }
    }

    private func notice(_ title: String, detail: String? = nil, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(Color.inkPrimary.opacity(0.2))
            Text(title).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
            if let detail {
                Text(detail).font(.archivo(13)).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    private var blockedNotice: some View {
        VStack(spacing: 14) {
            notice("You blocked @\(shownHandle)", detail: "Their posts and profile are hidden from you.", icon: "hand.raised")
            SocialPill(title: "UNBLOCK", style: .outlined) { Task { await viewModel.unblock(uid: uid) } }
        }
    }

    // MARK: Visible profile

    @ViewBuilder
    private var visibleContent: some View {
        HStack(spacing: 6) {
            KPIBlock(label: "Streak", value: "\(profile?.currentStreak ?? 0)D").frame(maxWidth: .infinity, alignment: .leading)
            KPIBlock(label: "This Wk", value: "\(stats.trainedDaysThisWeek)").frame(maxWidth: .infinity, alignment: .leading)
            KPIBlock(label: "Volume · 30D", value: unit.compactVolume(stats.volumeKg30d)).frame(maxWidth: .infinity, alignment: .leading)   // posted weights are kg
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

        SectionLabel(title: "This Week", meta: "\(stats.trainedDaysThisWeek) Of 7 Days")
            .padding(.top, 16).padding(.bottom, 6)

        ForEach(stats.week, id: \.day) { day in
            dayRow(day)
        }

        if relationship != .friends && relationship != .me {
            Text("YOU SEE THEIR PUBLIC SESSIONS · FRIENDS SEE MORE")
                .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(.top, 14)
        } else if (page?.posts ?? []).isEmpty {
            Text("NO POSTED SESSIONS YET").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(.top, 14)
        }
    }

    @ViewBuilder
    private func dayRow(_ day: (day: Date, post: WorkoutFeedItem?)) -> some View {
        let content = HStack {
            Text(day.day.formatted(.dateTime.weekday(.wide)))
                .font(.archivo(15, weight: .medium))
                .foregroundStyle(day.post == nil ? Color.inkMuted : Color.inkPrimary)
            Spacer()
            if let post = day.post {
                Text("\(post.workingSetCount) SETS").font(Font.spaceMono(10)).foregroundStyle(Color.inkMuted)
                Text("›").font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
            } else {
                Text("—").font(Font.spaceMono(10)).foregroundStyle(Color.inkFaint)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

        if let post = day.post {
            Button { openedPost = post } label: { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}
