import SwiftUI

// MARK: - Privacy & Legal  (More Screens.dc.html · 2i)
// Documents and data rights only — profile visibility and auto-share live in Settings › Privacy.

struct PrivacyLegalView: View {
    let onBack: () -> Void
    @State private var showDeleteConfirm = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "PRIVACY & LEGAL", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MoreSectionLabel(title: "LEGAL")
                    MoreRow(icon: "shield", label: "Privacy Policy") { openLegal() }
                    MoreRow(icon: "doc.text", label: "Terms of Service") { openLegal() }
                    MoreRow(icon: "doc.text", label: "Open-Source Licenses") { openLegal() }

                    MoreSectionLabel(title: "YOUR DATA")
                    MoreRow(icon: "square.and.arrow.down", label: "Download My Data", value: "JSON") { }
                    MoreRow(icon: "trash", label: "Delete Account", destructive: true, chevron: false) {
                        showDeleteConfirm = true
                    }

                    Text("Profile visibility and auto-share are in Settings › Privacy.")
                        .font(.archivo(13))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.top, 12)

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
    }

    /// Legal document URLs aren't defined yet; wire these once the hosted pages exist.
    private func openLegal() { }
}
