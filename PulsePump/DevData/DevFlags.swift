import Foundation

/// Runtime switches that only ever turn on in DEBUG builds (set by `DevDataService`, or by hand
/// with launch arguments such as `-devDataPlus 1`). In Release every flag is a constant `false`,
/// so fixture code paths are unreachable for real users.
enum DevFlags {
    /// `-useFirebaseEmulator 1`: the app talks to the local Firebase emulators.
    static var usesFirebaseEmulator: Bool { usesFirebaseEmulator(defaults: .standard) }

    static func usesFirebaseEmulator(defaults: UserDefaults) -> Bool {
        #if DEBUG
        defaults.bool(forKey: "useFirebaseEmulator")
        #else
        false
        #endif
    }

    /// Use the seeded in-memory social backend (`SocialFixtures`) instead of Firestore. DEBUG only,
    /// off by default, and never while the emulator is in use (the emulator has real data).
    static var socialFixtures: Bool { socialFixtures(defaults: .standard) }

    static func socialFixtures(defaults: UserDefaults) -> Bool {
        #if DEBUG
        !usesFirebaseEmulator(defaults: defaults) && defaults.bool(forKey: "devDataSocialFixtures")
        #else
        false
        #endif
    }

    /// Treat the user as a Pulse+ subscriber (StoreKit has no products on a simulator).
    static var plusOverride: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "devDataPlus")
        #else
        false
        #endif
    }
}
