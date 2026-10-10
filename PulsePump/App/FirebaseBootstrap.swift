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
    /// Project id the local emulators run under (`firebase emulators:start --project demo-pump`).
    static let emulatorProjectId = "demo-pump"

    private static func apply(_ config: FirebaseEmulatorConfig) {
        apply(config, to: FirebaseApp.app()!)
    }

    /// Points one app's Auth / Firestore / Functions at the emulators. Must run before that app is used.
    static func apply(_ config: FirebaseEmulatorConfig, to app: FirebaseApp) {
        Auth.auth(app: app).useEmulator(withHost: config.host, port: config.authPort)

        let firestore = Firestore.firestore(app: app)
        let settings = firestore.settings
        settings.host = "\(config.host):\(config.firestorePort)"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()   // no persistent cache across emulator resets
        firestore.settings = settings

        Functions.functions(app: app, region: functionsRegion).useEmulator(withHost: config.host, port: config.functionsPort)
        print("[Firebase] \(app.name) -> emulators at \(config.host): auth \(config.authPort), firestore \(config.firestorePort), functions \(config.functionsPort)")
    }

    /// A named secondary app under the emulator project id, already pointed at the emulators. Integration tests
    /// use one per simulated user so several accounts can be signed in at once without touching the default app.
    static func emulatorApp(named name: String, config: FirebaseEmulatorConfig) -> FirebaseApp {
        configure()
        if let existing = FirebaseApp.app(name: name) { return existing }
        // Options of a configured app are locked (and so are their copies): build a fresh object.
        let base = FirebaseApp.app()!.options
        let options = FirebaseOptions(googleAppID: base.googleAppID, gcmSenderID: base.gcmSenderID)
        options.apiKey = base.apiKey
        options.bundleID = base.bundleID
        options.projectID = emulatorProjectId
        FirebaseApp.configure(name: name, options: options)
        let app = FirebaseApp.app(name: name)!
        precondition(app.options.projectID == emulatorProjectId, "emulator apps must never use the real project")
        apply(config, to: app)
        return app
    }
    #endif
}
