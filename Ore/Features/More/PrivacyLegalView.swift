import SwiftUI

// MARK: - Privacy & Legal  (More Screens.dc.html · 2i)
// Documents and data rights only — profile visibility and auto-share live in Settings › Privacy.

struct PrivacyLegalView: View {
    let onBack: () -> Void
    @State private var showDeleteConfirm = false
    @Environment(\.modelContext) private var modelContext
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var exportError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "PRIVACY & LEGAL", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MoreSectionLabel(title: "LEGAL")
                    MoreRow(label: "Privacy policy", description: "How Ore handles your data.") { openLegal() }
                    MoreRow(label: "Terms of use", description: "The rules for using Ore and Supernova.") { openLegal() }

                    MoreSectionLabel(title: "YOUR DATA")
                    MoreRow(label: "Download my data", description: "A JSON backup of everything you have logged.", value: "JSON") { exportData() }
                    MoreRow(label: "Delete account", description: "Removes your account and data. Asks you to confirm.", destructive: true, chevron: false) {
                        showDeleteConfirm = true
                    }

                    HStack(spacing: 8) {
                        Rectangle().fill(Color.oreAccent).frame(width: 16, height: 16)
                        Text("ORE").font(.spaceMono(10, weight: .bold)).tracking(2)
                            .foregroundStyle(Color.inkPrimary)
                        Text("· VERSION \(version)").font(.spaceMono(9)).tracking(1)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 32)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .deleteAccountFlow(isPresented: $showDeleteConfirm)
        .sheet(isPresented: $showShare) { if let exportURL { ShareSheet(items: [exportURL]) } }
        .alert("Couldn't export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") {}
        } message: { Text(exportError ?? "") }
    }

    /// A JSON backup of every workout, through the share sheet.
    private func exportData() {
        do {
            let data = try DataExportService.exportWorkouts(from: modelContext)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ore_workouts.json")
            try data.write(to: url)
            exportURL = url
            showShare = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Legal document URLs aren't defined yet; wire these once the hosted pages exist.
    private func openLegal() { }
}
