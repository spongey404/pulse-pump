import SwiftUI

/// 6g — activity and privacy. "Needs you" is driven by real inbox items only: friend requests (fans
/// waiting for a follow back) and challenge invites. There is no event history to show, so there is
/// no "Earlier" list.
struct ActivityView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SocialScreenHeader(title: "ACTIVITY", onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(title: "Needs You", meta: viewModel.inboxCount == 0 ? nil : "\(viewModel.inboxCount)").padding(.top, 16).padding(.bottom, 6)

                    if viewModel.inboxCount == 0 {
                        Text("NOTHING NEEDS YOU RIGHT NOW")
                            .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            .frame(minHeight: 44, alignment: .leading)
                    }

                    ForEach(viewModel.fanRequests) { fan in
                        needsYouRow(
                            title: "\(fan.shownName) wants to be friends",
                            detail: fan.username.isEmpty ? "FOLLOWS YOU" : "@\(fan.username.uppercased()) FOLLOWS YOU",
                            accept: { Task { await viewModel.accept(fan.uid) } },
                            decline: { viewModel.ignore(fan.uid) }
                        )
                    }
                    ForEach(viewModel.pendingChallengeInvites) { invite in
                        needsYouRow(
                            title: "\(invite.fromUsername.isEmpty ? "Someone" : invite.fromUsername) invited you to \(invite.challengeName)",
                            detail: "CHALLENGE INVITE",
                            accept: { Task { await viewModel.respond(to: invite, accept: true) } },
                            decline: { Task { await viewModel.respond(to: invite, accept: false) } }
                        )
                    }

                    SectionLabel(title: "Privacy").padding(.top, 22).padding(.bottom, 6)
                    ForEach(PrivacyRow.allCases) { row in
                        PrivacyRowView(row: row, viewModel: viewModel)
                    }
                    Text("CHANGES APPLY TO POSTS YOU MAKE FROM NOW ON · SAVED TO YOUR ACCOUNT")
                        .font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(.top, 8)
                    if let error = viewModel.privacyService.lastError {
                        Text(error.uppercased()).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.signalDown).padding(.top, 6)
                    }

                    SectionLabel(title: "Safety").padding(.top, 22).padding(.bottom, 6)
                    NavigationLink {
                        BlockedUsersView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Text("Blocked people").font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                            Spacer()
                            Text("\(viewModel.blockedUsers.count)").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            Text("›").font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
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

    private func needsYouRow(title: String, detail: String, accept: @escaping () -> Void, decline: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 4)
            SocialPill(title: "ACCEPT", style: .filled, action: accept)
            SocialPill(title: "IGNORE", style: .outlined, action: decline)
        }
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

private struct PrivacyRowView: View {
    let row: PrivacyRow
    @Bindable var viewModel: SocialViewModel
    @State private var showPicker = false

    private var level: PrivacyLevel { viewModel.privacy[row] }

    var body: some View {
        Button { showPicker = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text(level.note(for: row)).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Text(row.label(for: level).uppercased()).font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.accentInk)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .confirmationDialog(row.title, isPresented: $showPicker) {
            ForEach(row.options) { option in
                Button(row.label(for: option)) { Task { await viewModel.setPrivacy(row, option) } }
            }
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
                                Text(blocked.displayName.isEmpty ? "Pump user" : blocked.displayName)
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
