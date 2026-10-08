import SwiftUI

/// Settings > "CLOUD SYNC": status, last synced time and a manual Sync now (Ledger rows).
struct CloudSyncSection: View {
    private var sync: SyncService { .shared }

    private var lastSyncedText: String {
        guard let date = sync.lastSyncedAt else { return "NEVER" }
        return date.formatted(.relative(presentation: .named)).uppercased()
    }

    var body: some View {
        MoreSectionLabel(title: "CLOUD SYNC")
        MoreRow(icon: statusIcon, label: "Status", value: sync.statusText.uppercased(), chevron: false)
        MoreRow(icon: "clock.arrow.circlepath", label: "Last Synced", value: lastSyncedText, chevron: false)
        MoreRow(icon: "arrow.triangle.2.circlepath", label: sync.status == .syncing ? "Syncing…" : "Sync Now",
                chevron: false) {
            guard sync.status != .syncing, sync.isRunning else { return }
            Task { await sync.syncNow() }
        }
        .opacity(sync.isRunning ? 1 : 0.5)
    }

    private var statusIcon: String {
        switch sync.status {
        case .idle: "checkmark.icloud"
        case .syncing: "icloud.and.arrow.up"
        case .offline: "icloud.slash"
        case .error: "exclamationmark.icloud"
        }
    }
}
