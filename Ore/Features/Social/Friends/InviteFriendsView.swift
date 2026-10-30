import SwiftUI

/// 5b — Invite friends, step 2. The challenge already exists by this point (created at the end of
/// 5a) — there is no create action here, only invites. Invites are `invites/{challengeId}_{toUid}`
/// documents; the invitee joins from their inbox.
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

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: "INVITE FRIENDS", onBack: nil) {
                Button("SKIP") { dismiss() }
                    .font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
            }

            Text("\(challenge.name.uppercased()) · \(challenge.metric.displayName.uppercased()) · ENDS \(challenge.endAt.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                .font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Color.inkMuted)
                        TextField("Search your friends", text: $searchText)
                            .font(.archivo(15))
                    }
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleStrong).frame(height: 1) }
                    .padding(.top, 14)

                    SectionLabel(title: "Your Friends", meta: "\(friends.count)").padding(.top, 22).padding(.bottom, 6)

                    if viewModel.friends.isEmpty {
                        Text("NO FRIENDS YET · FRIENDS ARE PEOPLE YOU FOLLOW WHO FOLLOW YOU BACK")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted).frame(minHeight: 44, alignment: .leading)
                    }
                    ForEach(friends, id: \.uid) { friend in
                        friendRow(friend)
                    }

                    SectionLabel(title: "Not On Ore").padding(.top, 24).padding(.bottom, 8)
                    ShareLink(item: "I started a challenge on Ore: \(challenge.name). Get the app and add me\(viewModel.myHandle.isEmpty ? "" : " (@\(viewModel.myHandle))") to join.") {
                        DashedAdd(title: "Share Invite", action: {})
                            .allowsHitTesting(false)
                    }
                    Text("PEOPLE YOU INVITE CAN JOIN UNTIL THE CHALLENGE ENDS · LATE JOINERS ARE SCORED FROM THE DAY THEY JOIN")
                        .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            DockedCTA(trailingCount: "\(invitedUids.count) INVITED", primaryLabel: "DONE ›", style: .quiet) { dismiss() }
        }
        .task { await viewModel.loadGraph() }
    }

    private func friendRow(_ friend: FirestoreUserProfile) -> some View {
        let isInvited = invitedUids.contains(friend.uid)
        return HStack(spacing: 12) {
            Avatar(initial: friend.shownName, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(friend.shownName).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    if !friend.username.isEmpty { Text("@\(friend.username)").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted) }
                }
                Text("\(friend.currentStreak)D STREAK").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            SocialPill(title: isInvited ? "INVITED" : "INVITE", style: isInvited ? .outlined : .filled, isDisabled: isInvited || inFlight.contains(friend.uid)) {
                // Invites can't be withdrawn from here, so INVITED is final once the write succeeds.
                inFlight.insert(friend.uid)
                Task {
                    if await viewModel.sendChallengeInvite(challenge: challenge, toUid: friend.uid) {
                        invitedUids.insert(friend.uid)
                    }
                    inFlight.remove(friend.uid)
                }
            }
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
