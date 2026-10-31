import Foundation
import Security

/// Where the free trial's start is kept, so deleting and reinstalling the app (or winding the clock back) doesn't restart or
/// stretch it. The start date and the latest date the app has seen live in the Keychain, which survives an app deletion;
/// `UserDefaults` still holds the date for installs that predate this and as a fallback if the Keychain can't be used.
protocol TrialDateStore {
    func read(_ key: String) -> Date?
    func write(_ date: Date, for key: String)
}

struct KeychainTrialDateStore: TrialDateStore {
    private let service = "com.pulse.PulsePump.trial"   // not renamed with the app: it would orphan the stored dates

    func read(_ key: String) -> Date? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data,
              let text = String(data: data, encoding: .utf8), let t = TimeInterval(text) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    func write(_ date: Date, for key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        let data = Data(String(date.timeIntervalSince1970).utf8)
        if SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

enum TrialAnchor {
    static let installKey = "appInstallDate"
    static let lastSeenKey = "trialLastSeen"

    /// The trial's start: the earliest of what the Keychain and `UserDefaults` remember, else now (and it is remembered).
    static func installDate(now: Date = Date(), defaults: UserDefaults = .standard, store: TrialDateStore = KeychainTrialDateStore()) -> Date {
        let known = [store.read(installKey), defaults.object(forKey: installKey) as? Date].compactMap { $0 }.min() ?? now
        if store.read(installKey) != known { store.write(known, for: installKey) }
        if (defaults.object(forKey: installKey) as? Date) != known { defaults.set(known, forKey: installKey) }
        return known
    }

    /// "Now" for trial maths: never earlier than the latest date seen, so setting the clock back doesn't extend the trial.
    static func trialNow(now: Date = Date(), store: TrialDateStore = KeychainTrialDateStore()) -> Date {
        let latest = max(now, store.read(lastSeenKey) ?? .distantPast)
        if latest > (store.read(lastSeenKey) ?? .distantPast) { store.write(latest, for: lastSeenKey) }
        return latest
    }
}
