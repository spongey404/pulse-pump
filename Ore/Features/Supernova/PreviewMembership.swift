import SwiftUI

/// A switch between "Supernova member" and "free" for comparing the two experiences on a test build. It exists only in DEBUG
/// builds: any Release or App Store build has no toggle and `forced` is always nil.
enum PreviewMembership {
    static let key = "previewMembership"   // "member" | "free" | absent (= the real state)

    #if DEBUG
    static let isAvailable = true
    /// The membership this build is pretending to have, or nil to use the real StoreKit state.
    static var forced: Bool? {
        switch UserDefaults.standard.string(forKey: key) {
        case "member": return true
        case "free": return false
        default: return DevFlags.plusOverride ? true : nil
        }
    }
    static func set(_ member: Bool) { UserDefaults.standard.set(member ? "member" : "free", forKey: key) }
    #else
    static let isAvailable = false
    static var forced: Bool? { nil }
    static func set(_ member: Bool) {}
    #endif
}

/// "PREVIEW · FREE | MEMBER" at the foot of More, on test builds only.
struct PreviewMembershipToggle: View {
    var isMember: Bool
    var onChange: () -> Void

    var body: some View {
        if PreviewMembership.isAvailable {
            VStack(alignment: .leading, spacing: 8) {
                Text("PREVIEW BUILD · SHOW AS").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                Picker("", selection: Binding(get: { isMember }, set: { PreviewMembership.set($0); onChange() })) {
                    Text("FREE").tag(false)
                    Text("MEMBER").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16).padding(.top, 24)
        }
    }
}
