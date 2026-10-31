import SwiftUI

/// 8b: activity and privacy. "Needs you" is driven by real inbox items only: friend requests (fans waiting for a follow back)
/// and challenge invites. There is no event history to show, so the design's "Earlier" list is omitted rather than invented.
struct ActivityView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MoreSectionLabel(title: "NEEDS YOU", ruled: false)
                        .overlay(alignment: .trailing) {
                            Text("\(viewModel.inboxCount)").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                                .padding(.trailing, 16).padding(.top, 14)
                                .opacity(viewModel.inboxCount == 0 ? 0 : 1)
                        }
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)

                    if viewModel.inboxCount == 0 {
                        Text("Nothing needs you right now.")
                            .font(.archivo(12)).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }

                    ForEach(viewModel.fanRequests) { fan in
                        needsYouRow(
                            name: fan.shownName,
                            title: "\(fan.shownName) wants to follow you",
                            detail: fan.username.isEmpty ? nil : "@\(fan.username)",
                            decline: "IGNORE", accept: "ACCEPT",
                            onAccept: { Task { await viewModel.accept(fan.uid) } },
                            onDecline: { viewModel.ignore(fan.uid) }
                        )
                    }
                    ForEach(viewModel.pendingChallengeInvites) { invite in
                        let from = invite.fromUsername.isEmpty ? "Someone" : invite.fromUsername
                        needsYouRow(
                            name: from,
                            title: "\(from) invited you",
                            detail: invite.challengeName,
                            decline: "DECLINE", accept: "JOIN",
                            onAccept: { Task { await viewModel.respond(to: invite, accept: true) } },
                            onDecline: { Task { await viewModel.respond(to: invite, accept: false) } }
                        )
                    }

                    MoreSectionLabel(title: "PRIVACY", ruled: false)
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    ForEach(PrivacyRow.allCases) { row in
                        PrivacyRowView(row: row, viewModel: viewModel)
                    }
                    if let error = viewModel.privacyService.lastError {
                        Text(error.uppercased()).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.signalDown)
                            .padding(.horizontal, 16).padding(.top, 8)
                    }

                    MoreSectionLabel(title: "SAFETY", ruled: false)
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    NavigationLink {
                        BlockedUsersView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 10) {
                            Text("Blocked people").font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                            Spacer()
                            Text("\(viewModel.blockedUsers.count)").font(.spaceMono(10)).tracking(0.8).foregroundStyle(Color.inkMuted)
                            Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(OreRowPressStyle())
                    Color.clear.frame(height: 30)
                }
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadGraph()
            await viewModel.loadInvites()
            await viewModel.restorePrivacy()
        }
    }

    /// SOCIAL overline, ACTIVITY title, and the back tile on the right (36 pt, radius 10, sunken).
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SOCIAL").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                Text("ACTIVITY").font(.archivo(26, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                    .accessibilityIdentifier(AX.nav.title("ACTIVITY"))
            }
            Spacer()
            Button { dismiss() } label: {
                Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary)
                    .frame(minWidth: 36, minHeight: 36)
                    .background(Color.surf2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier(AX.nav.back)
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    /// A request or invite: initial tile, title (16 bold) and detail (12 muted) left; a 32 pt outlined decline and a filled accept right.
    private func needsYouRow(name: String, title: String, detail: String?, decline: String, accept: String,
                             onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.surf2)
                .frame(width: 36, height: 36)
                .overlay(Text(name.prefix(1).uppercased()).font(.archivo(15, weight: .black)).foregroundStyle(Color.inkSecondary))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).font(.archivo(12)).foregroundStyle(Color.inkMuted).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Button(action: onDecline) {
                    Text(decline).font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 12).frame(height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.social.pill(decline))
                Button(action: onAccept) {
                    Text(accept).font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background { AccentFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.social.pill(accept))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

/// A privacy setting as a settings row: title, one sentence under it, the current level and a ›. Tapping asks for a new level.
private struct PrivacyRowView: View {
    let row: PrivacyRow
    @Bindable var viewModel: SocialViewModel
    @State private var showPicker = false

    private var level: PrivacyLevel { viewModel.privacy[row] }

    var body: some View {
        MoreRow(label: row.title, description: Self.sentence(row, level), value: row.label(for: level).uppercased()) { showPicker = true }
            .confirmationDialog(row.title, isPresented: $showPicker) {
                ForEach(row.options) { option in
                    Button(row.label(for: option)) { Task { await viewModel.setPrivacy(row, option) } }
                }
            }
    }

    /// What the current level means, as a sentence (the model's `note` is the older all-caps label).
    static func sentence(_ row: PrivacyRow, _ level: PrivacyLevel) -> String {
        switch (row, level) {
        case (.workoutPosts, .everyone): "Anyone on Ore sees your new sessions."
        case (.workoutPosts, .friendsOnly): "Friends see your sessions in their feed."
        case (.workoutPosts, .onlyMe): "New sessions stay in your history."
        case (.bodyMap, .everyone): "Shown on every new post and your profile."
        case (.bodyMap, .friendsOnly): "Friends see it; others see stats only."
        case (.bodyMap, .onlyMe): "Never shared."
        case (.globalLeaderboards, .onlyMe): "You're hidden from global boards."
        case (.globalLeaderboards, _): "Your name and rank in monthly challenges."
        case (.profile, .everyone): "Anyone can find and view you."
        case (.profile, .friendsOnly): "Only friends can view your profile."
        case (.profile, .onlyMe): "Your profile is private."
        }
    }
}

/// People I blocked, with UNBLOCK. Their profile is unreadable while blocked, so the name and handle
/// stored at block time are shown.
struct BlockedUsersView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: "BLOCKED", onBack: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.blockedUsers.isEmpty {
                        Text("YOU HAVEN'T BLOCKED ANYONE")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(.top, 24)
                    }
                    ForEach(viewModel.blockedUsers) { blocked in
                        HStack(spacing: 12) {
                            Avatar(initial: blocked.displayName.isEmpty ? blocked.username : blocked.displayName, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(blocked.displayName.isEmpty ? Brand.defaultUserName : blocked.displayName)
                                    .font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                                if !blocked.username.isEmpty {
                                    Text("@\(blocked.username)").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
                                }
                            }
                            Spacer()
                            SocialPill(title: "UNBLOCK", style: .outlined) { Task { await viewModel.unblock(uid: blocked.uid) } }
                        }
                        .frame(minHeight: 60)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadBlocked() }
    }
}
