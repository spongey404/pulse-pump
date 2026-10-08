import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// Where the local Firebase emulators listen (see `firebase.json`).
struct FirebaseEmulatorConfig: Equatable {
    var host: String
    var authPort: Int = 9099
    var firestorePort: Int = 8085
    var functionsPort: Int = 5001

    static let defaultHost = "127.0.0.1"

    /// Pure parsing of the launch arguments (`-useFirebaseEmulator 1`, `-firebaseEmulatorHost <host>`).
    /// Returns nil when the emulator is not requested.
    static func parse(useEmulator: Bool, host: String?) -> FirebaseEmulatorConfig? {
        guard useEmulator else { return nil }
        let trimmed = host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return FirebaseEmulatorConfig(host: trimmed.isEmpty ? defaultHost : trimmed)
    }

    static func from(defaults: UserDefaults) -> FirebaseEmulatorConfig? {
        parse(useEmulator: defaults.bool(forKey: "useFirebaseEmulator"),
              host: defaults.string(forKey: "firebaseEmulatorHost"))
    }
}

/// The single place that configures Firebase. Call `configure()` once at launch, before any
/// Auth / Firestore / Functions access (`PulsePumpApp.init`).
enum FirebaseBootstrap {
    /// Cloud Functions region (matches `firebase/functions`).
    static let functionsRegion = "australia-southeast1"

    private static var didConfigure = false

    static func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        if FirebaseApp.app() == nil { FirebaseApp.configure() }

        #if DEBUG
        if let emulator = FirebaseEmulatorConfig.from(defaults: .standard) {
            apply(emulator)
        }
        #endif
    }

    /// Cloud Functions in the project region (emulator-aware once `configure()` ran).
    static var functions: Functions { Functions.functions(region: functionsRegion) }

    #if DEBUG
    private static func apply(_ config: FirebaseEmulatorConfig) {
        Auth.auth().useEmulator(withHost: config.host, port: config.authPort)

        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.host = "\(config.host):\(config.firestorePort)"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()   // no persistent cache across emulator resets
        firestore.settings = settings

        functions.useEmulator(withHost: config.host, port: config.functionsPort)
        print("[Firebase] emulators at \(config.host): auth \(config.authPort), firestore \(config.firestorePort), functions \(config.functionsPort)")
    }
    #endif
}
