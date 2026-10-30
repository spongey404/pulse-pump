import Foundation

/// Every brand string in one place, so a rename is a one-file change. Compiled into the app and the widget
/// extension (so nothing in `OreShared` hardcodes a name either).
///
/// Plain-text surfaces (notifications, share-sheet text, emails, StoreKit display names) use
/// `membershipName` with NO asterisk. The asterisk belongs to branded UI only: see `SupernovaWordmark`.
enum Brand {
    /// This app.
    static let appName = "Ore"
    /// The paid membership that covers the apps. Always "Supernova" in code; the gold asterisk is a separate
    /// styled element (`SupernovaWordmark`), never part of the string.
    static let membershipName = "Supernova"

    /// Sibling apps. `driftName` is provisional (Stride's placeholder) and may change.
    static let tareName = "Tare"
    static let driftName = "Drift"
    static let siblingAppNames = [tareName, driftName]
    /// "Ore, Tare and Drift": the three apps one membership covers.
    static var allAppNames: [String] { [appName] + siblingAppNames }

    /// Deep links: `ore://…`. The pre-rebrand `pulsepump://…` links (shared template links, widgets already on
    /// a home screen) keep working.
    static let urlScheme = "ore"
    static let legacyURLSchemes = ["pulsepump"]
    static func isOwnScheme(_ scheme: String?) -> Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == urlScheme || legacyURLSchemes.contains(scheme)
    }
    /// Host of the link that opens the membership screen. `pulse-plus` is the old spelling.
    static let membershipLinkHosts = ["supernova", "pulse-plus"]

    /// Not final. Nothing may hardcode a company name: keep this nil until it is decided.
    static let companyName: String? = nil
    /// Placeholder until a support address exists.
    static let supportEmail: String? = nil

    /// Name shown for someone with no display name. Profiles written before the rebrand hold "Pump user".
    static let defaultUserName = "Ore user"
    static let legacyDefaultUserNames = ["Pump user"]
    static func isPlaceholderUserName(_ name: String) -> Bool {
        name == defaultUserName || legacyDefaultUserNames.contains(name)
    }

    /// Share-card watermark: the app name only.
    static var shareWatermark: String { appName }
}
