import SwiftUI

/// 6b — someone else's profile, honouring their privacy and my relationship to them:
/// - visible profile: stats, 30-day body map and this week's sessions, from their *posted* sessions
///   that I'm allowed to see (a friend sees friends-only posts, anyone else only public ones);
/// - private profile (friends-only / only-me, or a block): handle and FOLLOW only;
/// - deleted account: a plain "no longer available" state.
struct FriendProfileView: View {
    @Environment(\.weightUnit) private var unit
    @Environment(\.colorScheme) private var scheme
    let uid: String
    let handle: String
    let name: String
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var page: ProfilePage?
    @State private var openedPost: WorkoutFeedItem?
    @State private var confirmBlock = false
    @State private var menuOpen = false
    @State private var friendMenu = false
    @State private var range = 7
    @State private var challenging = false
    @State private var message: String?

    private var relationship: Relationship { viewModel.relationship(with: uid) }
    private var profile: FirestoreUserProfile? { page?.profile }
    private var shownName: String { profile?.shownName ?? name }
    private var shownHandle: String { (profile?.username.isEmpty == false ? profile?.username : nil) ?? handle }
    /// Posts name muscles by display name ("Chest"); match case-insensitively so a differently-cased key still colours its region.
    private var muscleSets: [String: Int] {
        stats.muscleSets30d.reduce(into: [:]) { $0[$1.key.capitalized, default: 0] += $1.value }
    }
    /// Their heaviest posted set per lift (never fabricated: from the sessions I am allowed to see).
    private var theirBest: [String: Double] {
        (page?.posts ?? []).flatMap(\.exercises).reduce(into: [:]) { acc, e in
            if let m = e.workingSets.map(\.weight).max(), m > (acc[e.name] ?? 0) { acc[e.name] = m }
        }
    }
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
        .sheet(isPresented: $challenging) {
            DirectChallengeSheet(friendUid: uid, friendName: shownName, theirBest: theirBest, viewModel: viewModel)
        }
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

    @ViewBuilder private var identityRow: some View {
        HStack(alignment: .center, spacing: 14) {
            PersonTile(name: shownName, size: 64, accentHex: memberHex)
            VStack(alignment: .leading, spacing: 4) {
                Text(page?.access == .restricted ? "Private profile" : shownName)
                    .font(.archivo(26, weight: .black)).foregroundStyle(Color.inkPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if memberHex != nil { SupernovaTag() }
                else if !shownHandle.isEmpty { Text("@\(shownHandle.uppercased())").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted) }
            }
            Spacer(minLength: 0)
            relationshipButton
        }
        .padding(16)
        if relationship == .friends, let pending = PendingDirectChallenges.pending(uid: uid) {
            Text(DirectChallengeModel.pendingLine(length: pending.length, name: shownName)).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                .foregroundStyle(Color.inkSecondary).padding(.horizontal, 16).padding(.bottom, 8)
        } else if relationship == .friends && page?.access == .visible {
            Button { challenging = true } label: {
                Text("CHALLENGE").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                    .padding(.horizontal, 14).frame(height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
            }
            .buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 8).accessibilityIdentifier("profile.challenge")
        }
        if relationship == .following {
            Text("Request sent. \(shownName) sees it in Activity.").font(.archivo(12)).foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 16).padding(.bottom, 8)
        }
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
                Button { friendMenu = true } label: { friendsLabel }
                    .buttonStyle(.plain)
                    .popover(isPresented: $friendMenu, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        PostMenuPopover {
                            PostMenuRow(title: viewModel.mutedUids.contains(uid) ? "Unmute" : "Mute") {
                                friendMenu = false
                                if viewModel.mutedUids.contains(uid) { viewModel.unmute(uid: uid) } else { viewModel.mute(uid: uid) }
                            }
                            PostMenuRow(title: "Remove friend", destructive: true) { friendMenu = false; Task { _ = await viewModel.unfollow(uid) } }
                        }
                    }
            case .following:
                AddFriendButton(requested: true, onAdd: {}, onCancel: { Task { _ = await viewModel.unfollow(uid) } })
            case .fan, .stranger:
                AddFriendButton(requested: false, onAdd: { Task { _ = await viewModel.follow(uid) } }, onCancel: {})
            }
        }
    }

    private var friendsLabel: some View {
        Text("✓ FRIENDS").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, 14).frame(height: 36)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
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

    private var rangeMuscles: [String: Int] {
        stats.muscleSets(inLast: range).reduce(into: [:]) { $0[$1.key.capitalized, default: 0] += $1.value }
    }
    private var rangeLevels: [String: Double] { BodyMapLevels.levels(muscleSets: rangeMuscles) }

    @ViewBuilder
    private var visibleContent: some View {
        HStack(spacing: 6) {
            ProfileFigure(label: "WORKOUTS", value: "\(profile?.totalWorkouts ?? 0)")
            ProfileFigure(label: "WK STREAK", value: "\(profile?.currentStreak ?? 0)")
            ProfileFigure(label: "FOLLOWERS", value: "\(profile?.fanCount ?? 0)")
            ProfileFigure(label: "FRIENDS", value: "\(profile?.friendCount ?? 0)")
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 17)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

        HStack {
            SocialSectionLabel(title: "TRAINING", ruled: false)
            Spacer()
            SegmentedChoice(options: [("7D", 7), ("30D", 30)], selection: $range).padding(.trailing, 16).padding(.top, 14)
        }
        let hero = stats.heroCounts(inLast: range)
        if !rangeLevels.isEmpty {
            BodyMapSwapView(levels: rangeLevels, member: memberHex != nil, accentHex: memberHex)
                .id(range)
                .frame(height: 400)
        }
        Text("\(hero.workouts) WORKOUT\(hero.workouts == 1 ? "" : "S") · \(unit.compactVolume(hero.volumeKg)) · ▲ \(hero.prs) PR\(hero.prs == 1 ? "" : "S")")
            .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 12)

        SocialSectionLabel(title: "RECENT WORKOUTS")
        ForEach((page?.posts ?? []).sorted { $0.date > $1.date }.prefix(8)) { post in recentRow(post) }

        if relationship != .friends && relationship != .me {
            Text("YOU SEE THEIR PUBLIC SESSIONS · FRIENDS SEE MORE")
                .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(16)
        } else if (page?.posts ?? []).isEmpty {
            Text("NO POSTED SESSIONS YET").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(16)
        }
    }

    private func recentRow(_ post: WorkoutFeedItem) -> some View {
        let lv = BodyMapLevels.levels(muscleSets: post.muscleSets)
        return Button { openedPost = post } label: {
            HStack(spacing: 12) {
                ZStack {
                    Color.surf
                    if let side = BodyMapLevels.trainedSides(lv).first {
                        BodyFigureView(side: side, levels: lv, member: memberHex != nil, accentHex: memberHex).padding(.top, 3)
                    }
                }
                .frame(width: 52, height: 72).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text((post.templateName ?? "Workout").capitalized).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                    Text("\(PostTime.ago(post.date)) · \(post.workingSetCount) SETS · \(unit.compactVolume(post.volumeKg))")
                        .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
                Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
            }
            .padding(.horizontal, 16).padding(.vertical, 8).contentShape(Rectangle())
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }
}

/// ADD FRIEND (accent): on tap the fill drains right to left (380 ms) and the label slides to REQUESTED (outlined); tap again cancels.
/// Only the button animates.
struct AddFriendButton: View {
    var requested: Bool
    let onAdd: () -> Void
    let onCancel: () -> Void
    @State private var shown: Bool?
    private var isRequested: Bool { shown ?? requested }

    var body: some View {
        Button {
            if isRequested { withAnimation(.easeOut(duration: 0.2)) { shown = false }; onCancel() }
            else { withAnimation(.easeInOut(duration: 0.38)) { shown = true }; onAdd() }
        } label: {
            ZStack {
                // The fill stays pinned to the right edge and its left edge runs right: it drains right to left in the sense of the
                // design (the colour leaves from the left).
                GeometryReader { g in
                    AccentFill(priority: 5).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(width: isRequested ? 0 : g.size.width).frame(maxWidth: .infinity, alignment: .trailing)
                }
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(isRequested ? Color.ruleStrong : Color.clear, lineWidth: 1)
                Text(isRequested ? "REQUESTED" : "ADD FRIEND").font(.spaceMono(9, weight: .bold)).tracking(1.5)
                    .foregroundStyle(isRequested ? Color.inkSecondary : Color.white)
                    .id(isRequested)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .frame(width: 112, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRequested ? "Requested. Tap to cancel" : "Add friend")
        .accessibilityIdentifier("profile.addFriend")
        .onChange(of: requested) { _, _ in shown = nil }
    }
}
