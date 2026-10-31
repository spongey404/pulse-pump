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
            SocialProfileHeader(overline: shownHandle.isEmpty ? "" : "@\(shownHandle.uppercased())", title: "", onBack: { dismiss() }) {
                if relationship != .me && page?.access != .unavailable {
                    Button { menuOpen = true } label: { HeaderSquareLabel(text: "···") }
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

    /// The accent of this person when they are a Supernova member (nil until the profile carries it: see `FriendMembership`).
    private var memberHex: String? { FriendMembership.accentHex(forUid: uid) }

    private var identityRow: some View {
        HStack(alignment: .center, spacing: 14) {
            PersonTile(name: shownName, size: 64, accentHex: memberHex)
            VStack(alignment: .leading, spacing: 4) {
                Text(page?.access == .restricted ? "Private profile" : shownName)
                    .font(.archivo(26, weight: .black)).foregroundStyle(Color.inkPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if memberHex != nil { SupernovaTag() }
            }
            Spacer(minLength: 0)
            relationshipButton
        }
        .padding(16)
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
                SocialSmallButton(title: "FRIENDS", style: .outlined, isStatic: true) {}
            case .following:
                SocialSmallButton(title: "FOLLOWING", style: .outlined, isStatic: true) {}
            case .fan:
                SocialSmallButton(title: "FOLLOW BACK", style: .filled) { Task { await viewModel.follow(uid) } }
            case .stranger:
                SocialSmallButton(title: "FOLLOW", style: .filled) { Task { await viewModel.follow(uid) } }
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
            SocialSmallButton(title: "UNBLOCK", style: .outlined) { Task { await viewModel.unblock(uid: uid) } }
        }
    }

    // MARK: Visible profile

    @ViewBuilder
    private var visibleContent: some View {
        HStack(spacing: 6) {
            ProfileFigure(label: "STREAK", value: "\(profile?.currentStreak ?? 0)D")
            ProfileFigure(label: "THIS WK", value: "\(stats.trainedDaysThisWeek)")
            ProfileFigure(label: "VOLUME", value: unit.compactVolume(stats.volumeKg30d))   // posted weights are kg
            ProfileFigure(label: "PRS", value: "\(stats.prs30d)", isPR: true)
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

        if !stats.muscleSets30d.isEmpty {
            SocialSectionLabel(title: "LAST 30 DAYS", ruled: false)
            HStack(spacing: 20) {
                bodyMap
                VStack(spacing: 8) {
                    ForEach(MuscleSetsFormat.top(stats.muscleSets30d, count: 5, abbreviated: false), id: \.label) { m in
                        HStack {
                            Text(m.label).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                            Spacer()
                            HStack(spacing: 0) {
                                Text("\(m.count)").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary)
                                Text(" SETS").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            }
                        }
                        .padding(.bottom, 6)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }

        SocialSectionLabel(title: "THIS WEEK", meta: "\(stats.trainedDaysThisWeek) OF 7 DAYS", ruled: false)
        Rectangle().fill(Color.dsHairLine).frame(height: 1)

        ForEach(stats.week, id: \.day) { day in
            dayRow(day)
        }

        if relationship != .friends && relationship != .me {
            Text("YOU SEE THEIR PUBLIC SESSIONS · FRIENDS SEE MORE")
                .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(16)
        } else if (page?.posts ?? []).isEmpty {
            Text("NO POSTED SESSIONS YET").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(16)
        }
    }

    /// The 30-day body map. A Supernova member's worked muscles are filled with Stardust in their accent; a free friend has none.
    private var bodyMap: some View {
        let heat = BodyHeat.Intensities(muscleSets: stats.muscleSets30d)
        return ZStack {
            BodyHeat(intensities: heat)
            if let hex = memberHex, let palette = FriendMembership.palette(hex: hex) {
                StardustMuscleOverlay(intensities: heat, palette: palette)
            }
        }
        .frame(width: 94, height: 150)
    }

    @ViewBuilder
    private func dayRow(_ day: (day: Date, post: WorkoutFeedItem?)) -> some View {
        let name = day.day.formatted(.dateTime.weekday(.abbreviated))
        if let post = day.post {
            Button { openedPost = post } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(name).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
                    }
                    Text([post.templateName, "\(post.workingSetCount) sets"].compactMap { $0 }.joined(separator: " · "))
                        .font(.archivo(12)).foregroundStyle(Color.inkMuted)
                }
                .padding(.vertical, 12).padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                Text(name).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkGhost)
                Spacer()
                Text("REST").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkGhost)
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
    }
}
