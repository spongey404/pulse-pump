import Testing
import Foundation
@testable import Ore

struct BrandTests {
    @Test func theMembershipNameNeverCarriesTheAsterisk() {
        #expect(Brand.membershipName == "Supernova")
        #expect(!Brand.membershipName.contains("*"), "the asterisk is a styled view, so plain-text surfaces stay clean")
        #expect(!Brand.appName.contains("*"))
    }

    @Test func oldAndNewLinkSchemesBothOpenTheApp() {
        #expect(Brand.isOwnScheme("ore"))
        #expect(Brand.isOwnScheme("pulsepump"), "template links shared before the rename keep working")
        #expect(Brand.isOwnScheme("ORE"))
        #expect(!Brand.isOwnScheme("https"))
        #expect(!Brand.isOwnScheme(nil))
    }

    @Test func theOldMembershipLinkHostStillResolves() {
        #expect(Brand.membershipLinkHosts.contains("supernova"))
        #expect(Brand.membershipLinkHosts.contains("pulse-plus"))
    }

    @Test func profilesWrittenBeforeTheRenameStillCountAsHavingNoName() {
        #expect(Brand.isPlaceholderUserName("Pump user"))
        #expect(Brand.isPlaceholderUserName(Brand.defaultUserName))
        #expect(!Brand.isPlaceholderUserName("Alex"))
    }

    @Test func noCompanyNameIsHardcoded() {
        #expect(Brand.companyName == nil)
    }

    @Test func theThreePlansHaveMonthlyAndYearlyPlaceholderProducts() {
        #expect(SupernovaTier.allCases.map(\.appCount) == [1, 2, 3])
        #expect(Set(SupernovaTier.allProductIds).count == 6)
        #expect(SupernovaTier.oneApp.productId(yearly: false) == "supernova.1app.monthly")
        #expect(SupernovaTier.allApps.productId(yearly: true) == "supernova.allapps.yearly")
        #expect(SupernovaTier.allProductIds.allSatisfy { !$0.contains("*") })
    }

    @Test func templateShareLinksUseTheNewScheme() {
        #expect(TemplateShareService.shareURLString(for: WorkoutTemplate(name: "X")).hasPrefix("ore://template"))
    }
}
