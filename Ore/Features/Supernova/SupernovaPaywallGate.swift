import Foundation

extension Notification.Name {
    /// Posted when the first-run flow ends and the Supernova paywall should be shown.
    static let showSupernovaPaywall = Notification.Name("showSupernovaPaywall")
}

/// When the full-screen Supernova paywall appears: once, at the end of first-run onboarding (after the tutorial,
/// or straight after onboarding when the tutorial was declined), and never for someone who already has Supernova.
/// Pure rules over plain values, so they are testable; `UserDefaultsStore` reads and writes the real flags.
enum SupernovaPaywallGate {
    /// Set when onboarding completes; cleared when the paywall is shown.
    static let pendingKey = "supernovaPaywallPending"
    /// Set once the paywall has been shown, so it is never shown twice.
    static let shownKey = "supernovaPaywallShown"

    static func shouldShow(isMember: Bool, pending: Bool, alreadyShown: Bool) -> Bool {
        pending && !alreadyShown && !isMember
    }

    /// True for someone who already has Supernova (a subscription, or the DEBUG override).
    static func isMember(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: SupernovaService.subscribedMirrorKey) || DevFlags.plusOverride
    }

    /// Onboarding finished: the paywall is due once the tutorial (or onboarding itself) ends.
    static func markPending(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: shownKey) else { return }
        defaults.set(true, forKey: pendingKey)
    }

    static func shouldShowNow(_ defaults: UserDefaults = .standard) -> Bool {
        shouldShow(isMember: isMember(defaults), pending: defaults.bool(forKey: pendingKey), alreadyShown: defaults.bool(forKey: shownKey))
    }

    /// The paywall is on screen: it has been shown, and is no longer pending.
    static func markShown(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: shownKey)
        defaults.set(false, forKey: pendingKey)
    }
}
