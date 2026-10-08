import Foundation

/// Runtime switches that only ever turn on in DEBUG builds (set by `DevDataService`, or by hand
/// with launch arguments such as `-devDataPlus 1`). In Release every flag is a constant `false`,
/// so fixture code paths are unreachable for real users.
enum DevFlags {
    /// Show the built-in demo friends / feed / challenges when Firestore has nothing to show.
    /// Firestore users can't be created locally, so social screens need these fixtures in dev.
    static var socialFixtures: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "devDataSocialFixtures")
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
