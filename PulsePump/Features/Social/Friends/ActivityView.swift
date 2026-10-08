import SwiftUI

/// 6g — activity and privacy.
struct ActivityView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    // Stubbed history — the app doesn't log a like/join event feed today.
    // TODO: back with a real event-log collection once one exists.
    private var earlierEvents: [(text: String, time: String)] {
        guard DevFlags.socialFixtures else { return [] }
        return [("Priya liked your post", "2H"), ("Jay joined Bench 100 Club", "1D")]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                Text("ACTIVITY").font(.archivo(22, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !viewModel.pendingRequests.isEmpty || !viewModel.pendingChallengeInvites.isEmpty {
                        SectionLabel(title: "Needs You").padding(.top, 16).padding(.bottom, 6)
                        ForEach(viewModel.pendingRequests, id: \.docId) { request in
                            needsYouRow(
                                title: "\(request.profile?.displayName ?? "Someone") wants to be friends",
                                accept: { Task { await viewModel.acceptFriendRequest(docId: request.docId) } },
                                decline: { Task { await viewModel.removeFriend(docId: request.docId) } }
                            )
                        }
                        ForEach(viewModel.pendingChallengeInvites, id: \.docId) { entry in
                            needsYouRow(
                                title: "\(entry.invite.fromUsername) invited you to \(entry.invite.challengeName)",
                                accept: { Task { await viewModel.respondToChallengeInvite(docId: entry.docId, accept: true) } },
                                decline: { Task { await viewModel.respondToChallengeInvite(docId: entry.docId, accept: false) } }
                            )
                        }
                    }

                    SectionLabel(title: "Earlier").padding(.top, 22).padding(.bottom, 6)
                    ForEach(earlierEvents, id: \.text) { event in
                        HStack {
                            Text(event.text).font(.archivo(14)).foregroundStyle(Color.inkPrimary)
                            Spacer()
                            Text(event.time).font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
                        }
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }

                    SectionLabel(title: "Privacy").padding(.top, 22).padding(.bottom, 6)
                    ForEach(PrivacyRow.allCases) { row in
                        PrivacyRowView(row: row)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadChallengeInvites()
        }
    }

    private func needsYouRow(title: String, accept: @escaping () -> Void, decline: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
            Spacer()
            Button("ACCEPT", action: accept)
                .font(Font.spaceMono(9, weight: .bold)).tracking(1).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.pumpAccent).clipShape(RoundedRectangle(cornerRadius: 8))
            Button("IGNORE", action: decline)
                .font(Font.spaceMono(9, weight: .bold)).tracking(1).foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

private struct PrivacyRowView: View {
    let row: PrivacyRow
    @AppStorage private var rawValue: String
    @State private var showPicker = false

    init(row: PrivacyRow) {
        self.row = row
        _rawValue = AppStorage(wrappedValue: PrivacyLevel.friendsOnly.rawValue, row.storageKey)
    }

    private var level: PrivacyLevel { PrivacyLevel(rawValue: rawValue) ?? .friendsOnly }

    var body: some View {
        Button { showPicker = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text(level.note(for: row)).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Text(level.displayName.uppercased()).font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.accentInk)
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .confirmationDialog(row.title, isPresented: $showPicker) {
            ForEach(PrivacyLevel.allCases) { option in
                Button(option.displayName) { rawValue = option.rawValue }
            }
        }
    }
}
