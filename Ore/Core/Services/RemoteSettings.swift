import Foundation
import FirebaseCore
import FirebaseRemoteConfig

/// Settings that can change without an app release, from Firebase Remote Config (edit them in the Firebase console):
/// - `supernova_trial_months` (number, 0–12): free-trial length, see `SupernovaTrial`.
/// - `starfield_config` (JSON string): replaces `starfield.config.json`, see `StarFieldConfigStore`.
/// - `signup_config` (JSON string): replaces `signup.config.json`, see `SignupConfigStore`.
/// Every value has an in-app default, so the app works offline and before the first fetch; a bad value is ignored.
@MainActor
enum RemoteSettings {
    static let starFieldKey = "starfield_config"
    static let signupKey = "signup_config"

    /// Pure: applies fetched values. Missing or invalid ones leave the current settings alone.
    static func apply(trialMonths: Int?, starFieldJSON: String?, signupJSON: String? = nil) {
        if let m = trialMonths, SupernovaTrial.allowedMonths.contains(m) { SupernovaTrial.months = m }
        if let json = starFieldJSON, !json.isEmpty, let data = json.data(using: .utf8) {
            StarFieldConfigStore.shared.applyRemote(json: data)
        }
        if let json = signupJSON, !json.isEmpty, let data = json.data(using: .utf8) {
            SignupConfigStore.shared.applyRemote(json: data)
        }
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
        rc.setDefaults([SupernovaTrial.remoteKey: NSNumber(value: SupernovaTrial.defaultMonths), starFieldKey: "" as NSString, signupKey: "" as NSString])
        Task {
            guard (try? await rc.fetchAndActivate()) != nil else { return }
            let trial = rc.configValue(forKey: SupernovaTrial.remoteKey)
            apply(trialMonths: trial.source == .remote ? trial.numberValue.intValue : nil,
                  starFieldJSON: rc.configValue(forKey: starFieldKey).stringValue,
                  signupJSON: rc.configValue(forKey: signupKey).stringValue)
        }
    }
}
