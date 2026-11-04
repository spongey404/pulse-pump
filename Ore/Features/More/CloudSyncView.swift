import SwiftUI

/// More › Cloud Sync: status, when it last synced and a SYNC NOW button. Real data only (`SyncService`).
struct CloudSyncView: View {
    /// Supernova member: free sees the locked state instead of the status and SYNC NOW.
    var isMember = true
    let onBack: () -> Void
    private var sync: SyncService { .shared }

    private var lastSyncedText: String {
        guard let date = sync.lastSyncedAt else { return "NEVER" }
        return date.formatted(.relative(presentation: .named)).uppercased()
    }

    /// The free state: what the screen is, and the one way to unlock it (the Supernova paywall).
    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("CLOUD SYNC · SUPERNOVA").font(.spaceMono(9, weight: .bold)).tracking(2).foregroundStyle(Color.inkPrimary)
                Text("*").font(.archivo(13, weight: .black)).foregroundStyle(SupernovaAsterisk.color)
            }
            Text("Status, last synced and SYNC NOW are part of Supernova.")
                .font(.archivo(13)).foregroundStyle(Color.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Button { MoreRouter.shared.pendingSupernova = true } label: {
                HStack {
                    HStack(spacing: 0) { Text("GO SUPERNOVA").font(.archivo(14, weight: .black)).tracking(0.6); Text("*").foregroundStyle(SupernovaAsterisk.color) }
                    Spacer(minLength: 0)
                    Text("›").font(.archivo(14, weight: .black))
                }
                .foregroundStyle(Color.inkPrimary).padding(.horizontal, 14).frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.cloudSync.lockedCTA)
        }
        .padding(16).background(Color.surf).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ruleStrong, lineWidth: 1))
        .padding(16).accessibilityElement(children: .contain).accessibilityIdentifier(AX.cloudSync.locked)
    }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "CLOUD SYNC", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MorePageIntro(text: "Your workouts, templates and settings back up to your account and come back on any device you sign in on.")
                    if isMember {
                        MoreSectionLabel(title: "STATUS")
                        MoreRow(label: "Status", value: sync.statusText.uppercased(), chevron: false, isStatic: true)
                        MoreRow(label: "Last synced", value: lastSyncedText, chevron: false, isStatic: true)
                    } else {
                        lockedCard
                    }
                }
            }
            if isMember {
                OrePageFooter {
                    OrePageCTA(title: sync.status == .syncing ? "SYNCING…" : "SYNC NOW", disabled: !sync.isRunning || sync.status == .syncing) {
                        guard sync.status != .syncing, sync.isRunning else { return }
                        Task { await sync.syncNow() }
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}
