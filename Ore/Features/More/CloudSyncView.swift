import SwiftUI

/// More › Cloud Sync: status, when it last synced and a SYNC NOW button. Real data only (`SyncService`).
struct CloudSyncView: View {
    let onBack: () -> Void
    private var sync: SyncService { .shared }

    private var lastSyncedText: String {
        guard let date = sync.lastSyncedAt else { return "NEVER" }
        return date.formatted(.relative(presentation: .named)).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "CLOUD SYNC", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MorePageIntro(text: "Your workouts, templates and settings back up to your account and come back on any device you sign in on.")
                    MoreSectionLabel(title: "STATUS")
                    MoreRow(label: "Status", value: sync.statusText.uppercased(), chevron: false) { }
                    MoreRow(label: "Last synced", value: lastSyncedText, chevron: false) { }
                }
            }
            OrePageFooter {
                OrePageCTA(title: sync.status == .syncing ? "SYNCING…" : "SYNC NOW", disabled: !sync.isRunning || sync.status == .syncing) {
                    guard sync.status != .syncing, sync.isRunning else { return }
                    Task { await sync.syncNow() }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}
