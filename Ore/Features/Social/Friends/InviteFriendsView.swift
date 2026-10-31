import SwiftUI

/// 6b — Invite friends, step 2. The challenge already exists by this point (created at the end of
/// step 1) — there is no create action here, only invites. Invites are `invites/{challengeId}_{toUid}`
/// documents; the invitee joins from their inbox. Each friend shows when they last trained, from the posts the feed has loaded.
struct InviteFriendsView: View {
    @Bindable var viewModel: SocialViewModel
    let challenge: SocialChallenge

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var invitedUids: Set<String> = []
    @State private var inFlight: Set<String> = []

    private var friends: [FirestoreUserProfile] {
        guard !searchText.isEmpty else { return viewModel.friends }
        return viewModel.friends.filter { $0.shownName.localizedCaseInsensitiveContains(searchText) || $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    private var label: String {
        "\(challenge.name) · \(challenge.metric.displayName) · ends \(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)))".uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            ChallengeHeader(label: label, title: "INVITE FRIENDS", onBack: nil) {
                ChallengeHeaderTextButton(title: "SKIP") { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Search friends", text: $searchText)
                        .font(.archivo(15))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal, 16).padding(.top, 14)

                    SectionLabel(title: "Friends", meta: invitedUids.isEmpty ? nil : "\(invitedUids.count) INVITED")
                        .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)

                    if viewModel.friends.isEmpty {
                        Text("NO FRIENDS YET · FRIENDS ARE PEOPLE YOU FOLLOW WHO FOLLOW YOU BACK")
                            .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    VStack(spacing: 0) {
                        ForEach(friends, id: \.uid) { friend in
                            friendRow(friend)
                        }
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    SectionLabel(title: "Not on \(Brand.appName)")
                        .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
                    ShareLink(item: "I started a challenge on \(Brand.appName): \(challenge.name). Get the app and add me\(viewModel.myHandle.isEmpty ? "" : " (@\(viewModel.myHandle))") to join.") {
                        Text("SHARE INVITE LINK")
                            .font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    Text("People you invite can join until the challenge ends. Late joiners are scored from the day they join.")
                        .font(.archivo(12)).foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SocialDock {
                SocialCTA(title: "DONE", info: invitedUids.isEmpty ? nil : "\(invitedUids.count) INVITED", id: AX.row("Done")) { dismiss() }
            }
        }
        .task {
            await viewModel.loadGraph()
            if viewModel.feedItems.isEmpty { await viewModel.loadFeed() }
        }
    }

    /// "Trained today" / "yesterday" / "N days ago", from the newest post of theirs the feed has; nil when none is loaded.
    private func lastTrained(_ uid: String, now: Date = Date()) -> String? {
        guard let date = viewModel.feedItems.filter({ $0.userId == uid }).map(\.date).max() else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Trained today"
        case 1: return "Trained yesterday"
        default: return "Trained \(days) days ago"
        }
    }

    private func friendRow(_ friend: FirestoreUserProfile) -> some View {
        let isInvited = invitedUids.contains(friend.uid)
        let detail = lastTrained(friend.uid) ?? (friend.username.isEmpty ? nil : "@\(friend.username)")
        return HStack(spacing: 12) {
            ChallengeAvatar(name: friend.shownName, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(friend.shownName).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                if let detail { Text(detail).font(.archivo(12)).foregroundStyle(Color.inkMuted) }
            }
            Spacer(minLength: 8)
            SocialSmallAction(title: isInvited ? "INVITED" : "INVITE", style: isInvited ? .outlined : .filled,
                              disabled: inFlight.contains(friend.uid)) {
                // Invites can't be withdrawn from here, so INVITED is final once the write succeeds.
                guard !isInvited else { return }
                inFlight.insert(friend.uid)
                Task {
                    if await viewModel.sendChallengeInvite(challenge: challenge, toUid: friend.uid) {
                        invitedUids.insert(friend.uid)
                    }
                    inFlight.remove(friend.uid)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
