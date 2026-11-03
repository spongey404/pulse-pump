import Foundation

/// The Supernova membership is one subscription that covers the apps, sold as three plans (1 app, 2 apps,
/// all 3), each monthly or yearly.
///
/// These product ids are PLACEHOLDERS: constants only, until the products exist in App Store Connect. No purchase
/// logic reads them yet; the live subscription still uses the ids in `SupernovaService`.
enum SupernovaTier: String, CaseIterable, Identifiable {
    case oneApp = "1app"
    case twoApps = "2apps"
    case allApps = "allapps"

    var id: String { rawValue }

    /// How many apps the plan covers.
    var appCount: Int {
        switch self {
        case .oneApp: 1
        case .twoApps: 2
        case .allApps: 3
        }
    }
    var title: String {
        switch self {
        case .oneApp: "1 app"
        case .twoApps: "2 apps"
        case .allApps: "All 3 apps"
        }
    }
    func productId(yearly: Bool) -> String { "supernova.\(rawValue).\(yearly ? "yearly" : "monthly")" }

    static var allProductIds: [String] {
        allCases.flatMap { [$0.productId(yearly: false), $0.productId(yearly: true)] }
    }
}
