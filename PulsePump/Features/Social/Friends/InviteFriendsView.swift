import SwiftUI

/// 5b — Invite friends, step 2. The challenge already exists by this point (created at the
/// end of 5a) — there is no create action here, only invites.
struct InviteFriendsView: View {
    @Bindable var viewModel: SocialViewModel
    let challengeId: String
    let challengeName: String
    let metricLabel: String
    let windowLabel: String

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var invitedUids: Set<String> = []

    private var friends: [FirestoreUserProfile] {
        guard !searchText.isEmpty else { return viewModel.friends }
        return viewModel.friends.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) || $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("INVITE FRIENDS").font(.archivo(22, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                Spacer()
                Button("SKIP") { dismiss() }
                    .font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            Text("\(challengeName.uppercased()) · \(metricLabel.uppercased()) · \(windowLabel)")
                .font(Font.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Color.inkMuted)
                        TextField("Search by name or handle", text: $searchText)
                            .font(.archivo(15))
                    }
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleStrong).frame(height: 1) }
                    .padding(.top, 14)

                    SectionLabel(title: "Your Friends", meta: "\(friends.count)").padding(.top, 22).padding(.bottom, 6)

                    ForEach(friends, id: \.uid) { friend in
                        friendRow(friend)
                    }

                    SectionLabel(title: "Not On Pump").padding(.top, 24).padding(.bottom, 8)
                    if let url = URL(string: "https://pulsepump.app/invite?challenge=\(challengeId)&ref=\(viewModel.currentUid ?? "")") {
                        ShareLink(item: url) {
                            DashedAdd(title: "Share Invite Link", action: {})
                                .allowsHitTesting(false)
                        }
                    }
                    Text("THE LINK STAYS OPEN FOR THE WHOLE CHALLENGE · LATE JOINERS ARE SCORED FROM THE DAY THEY JOIN")
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
        .task { await viewModel.loadFriends() }
    }

    private func friendRow(_ friend: FirestoreUserProfile) -> some View {
        let isInvited = invitedUids.contains(friend.uid)
        return HStack(spacing: 12) {
            Avatar(initial: friend.displayName, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(friend.displayName).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text("@\(friend.username)").font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
                }
                Text("\(friend.currentStreak)D STREAK").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button {
                if isInvited {
                    invitedUids.remove(friend.uid)
                } else {
                    invitedUids.insert(friend.uid)
                    Task { await viewModel.sendChallengeInvite(challengeId: challengeId, challengeName: challengeName, toUid: friend.uid) }
                }
            } label: {
                Text(isInvited ? "INVITED" : "INVITE")
                    .font(Font.spaceMono(9, weight: .bold)).tracking(1.2)
                    .foregroundStyle(isInvited ? Color.inkMuted : .white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(isInvited ? Color.clear : Color.pumpAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isInvited ? Color.ruleStrong : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
