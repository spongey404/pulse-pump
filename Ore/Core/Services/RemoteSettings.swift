import Foundation
import FirebaseCore
import FirebaseRemoteConfig

/// Settings that can change without an app release, from Firebase Remote Config (edit them in the Firebase console):
/// - `supernova_trial_months` (number, 0–12): free-trial length, see `SupernovaTrial`.
/// - `stardust_config` (JSON string): replaces `stardust.config.json`, see `StardustConfigStore`.
/// - `signup_config` (JSON string): replaces `signup.config.json`, see `SignupConfigStore`.
/// - `supernova_transition_config` (JSON string): replaces `supernovaTransition.config.json`.
/// - `supernova_member_config` (JSON string): replaces `supernovaMember.config.json` (member page and card, accent palettes).
/// - `bodymap_config` (JSON string): replaces `bodymap.config.json` (body map heat, reveal and member Stardust).
/// Every value has an in-app default, so the app works offline and before the first fetch; a bad value is ignored.
@MainActor
enum RemoteSettings {
    static let stardustKey = "stardust_config"
    /// The key before the rename: still read for one release when `stardust_config` isn't set in the console.
    static let legacyStardustKey = "starfield_config"
    static let signupKey = "signup_config"
    static let transitionKey = "supernova_transition_config"
    static let memberKey = "supernova_member_config"
    static let bodyMapKey = "bodymap_config"

    /// Pure: applies fetched values. Missing or invalid ones leave the current settings alone.
    static func apply(trialMonths: Int?, stardustJSON: String?, signupJSON: String? = nil, transitionJSON: String? = nil, memberJSON: String? = nil, bodyMapJSON: String? = nil) {
        if let m = trialMonths, SupernovaTrial.allowedMonths.contains(m) { SupernovaTrial.months = m }
        if let json = stardustJSON, !json.isEmpty, let data = json.data(using: .utf8) {
            StardustConfigStore.shared.applyRemote(json: data)
        }
        if let json = signupJSON, !json.isEmpty, let data = json.data(using: .utf8) {
            SignupConfigStore.shared.applyRemote(json: data)
        }
        if let json = transitionJSON, !json.isEmpty, let data = json.data(using: .utf8) {
            SupernovaTransitionConfigStore.shared.applyRemote(json: data)
        }
        if let json = memberJSON, !json.isEmpty, let data = json.data(using: .utf8) {
            SupernovaMemberConfigStore.shared.applyRemote(json: data)
        }
        if let json = bodyMapJSON, !json.isEmpty, let data = json.data(using: .utf8) {
            BodyMapConfigStore.shared.applyRemote(json: data)
        }
    }

    /// The new key's value, else the old key's (one release of fallback after the rename).
    static func firstNonEmpty(_ new: String?, _ legacy: String?) -> String? {
        if let new, !new.isEmpty { return new }
        return legacy
    }

    /// Fetches in the background at launch. Not run under tests or against the emulators (no Remote Config emulator).
    static func start() {
        let env = ProcessInfo.processInfo.environment
        guard env["XCTestConfigurationFilePath"] == nil, !UserDefaults.standard.bool(forKey: "useFirebaseEmulator"),
              FirebaseApp.app() != nil else { return }
        let rc = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        rc.configSettings = settings
        rc.setDefaults([SupernovaTrial.remoteKey: NSNumber(value: SupernovaTrial.defaultMonths), stardustKey: "" as NSString, legacyStardustKey: "" as NSString, signupKey: "" as NSString, transitionKey: "" as NSString, memberKey: "" as NSString, bodyMapKey: "" as NSString])
        Task {
            guard (try? await rc.fetchAndActivate()) != nil else { return }
            let trial = rc.configValue(forKey: SupernovaTrial.remoteKey)
            apply(trialMonths: trial.source == .remote ? trial.numberValue.intValue : nil,
                  stardustJSON: Self.firstNonEmpty(rc.configValue(forKey: stardustKey).stringValue, rc.configValue(forKey: legacyStardustKey).stringValue),
                  signupJSON: rc.configValue(forKey: signupKey).stringValue,
                  transitionJSON: rc.configValue(forKey: transitionKey).stringValue,
                  memberJSON: rc.configValue(forKey: memberKey).stringValue,
                  bodyMapJSON: rc.configValue(forKey: bodyMapKey).stringValue)
        }
    }
}
