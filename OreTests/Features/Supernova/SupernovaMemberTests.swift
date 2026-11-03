import Testing
import Foundation
import CoreGraphics
@testable import Ore

@MainActor
struct SupernovaMemberTests {
    private let m = SupernovaMemberConfig.fallback

    @Test func theBundledJSONEqualsTheFallback() throws {
        let url = try #require(Bundle.main.url(forResource: "supernovaMember.config", withExtension: "json"))
        #expect(try #require(SupernovaMemberConfig.load(from: Data(contentsOf: url))) == m)
    }

    @Test func theHeadlineIsTheFirstNonZeroNumberAndNeverAZero() {
        #expect(SupernovaOverview.headline(prs: 5, suggested: 12, recaps: 3) == .init(number: 5, text: "PRs came from a suggested weight."))
        #expect(SupernovaOverview.headline(prs: 0, suggested: 12, recaps: 3) == .init(number: 12, text: "sets used a suggested weight."))
        #expect(SupernovaOverview.headline(prs: 0, suggested: 0, recaps: 3) == .init(number: 3, text: "weekly recaps sent."))
        #expect(SupernovaOverview.headline(prs: 1, suggested: 0, recaps: 0)?.text == "PR came from a suggested weight.")
        #expect(SupernovaOverview.headline(prs: 0, suggested: 0, recaps: 0) == nil, "a brand-new member gets a prompt, not a 0")
        #expect(SupernovaOverview.emptyHeadline == "Your first suggested weight is waiting in your next session.")
    }

    @Test func theGridShowsADashForZeroAndTheSectionWaitsForARealNumber() {
        #expect(SupernovaOverview.cell(0) == "—" && SupernovaOverview.cell(7) == "7")
        #expect(!SupernovaOverview.showsStats(prs: 0, suggested: 0, lagging: 0, recaps: 0))
        #expect(SupernovaOverview.showsStats(prs: 0, suggested: 0, lagging: 1, recaps: 0))
        #expect(SupernovaOverview.showsStats(prs: 0, suggested: 2, lagging: 0, recaps: 0))
    }

    @Test func theDesignsPalettesAndNumbers() {
        #expect(m.picker.presets.map { $0[0] } == ["SKY", "PINK", "RED", "PURPLE", "GREEN", "CYAN", "ROSE", "GOLD", "SILVER", "BLACK", "WHITE"])
        #expect(m.picker.presets.map { $0[1] } == ["#3DB8FF", "#FD4A9F", "#FF001E", "#8C0099", "#009945", "#00EBEB", "#FD6892", "#FCC01D", "#C0C0C0", "#000000", "#FFFFFF"])
        #expect(m.picker.recentLimit == 11 && m.picker.holdDelayMs == 380 && !m.picker.lightTextOnLightAccents)
        #expect(m.picker.palette.lightStops == [62, 84, 100] && m.picker.palette.darkStops == [0, 16, 38])
        #expect(m.page.count == 900 && m.page.coverage == 0.65 && m.page.maskStops == [[0, 1], [0.51, 1], [0.59, 0.6], [0.67, 0.2], [0.73, 0]])
        #expect(m.card.radius == 14 && m.card.padH == 18 && m.card.padV == 16 && m.card.gap == 16 && m.card.fps == 30)
        #expect(m.transition.content.groups == 4 && m.transition.content.bannerItems == 3 && m.transition.maskRadiusStart == 14)
        #expect(m.transition.open.maskMs == 560 && m.transition.open.flyerMs == 760 && m.transition.close.ms == 560)
    }

    @Test func remoteConfigIsValidated() throws {
        let store = SupernovaMemberConfigStore()
        var broken = m; broken.picker.presets = []
        #expect(!store.applyRemote(json: try JSONEncoder().encode(broken)))
        var noDefault = m; noDefault.picker.defaultHex = "nope"
        #expect(!store.applyRemote(json: try JSONEncoder().encode(noDefault)))
        var badCurve = m; badCurve.picker.holdHue = [[Double.infinity, 1]]
        #expect(!store.applyRemote(json: (try? JSONEncoder().encode(badCurve)) ?? Data()), "non-finite numbers can't even be encoded; either way it is not applied")
        var tuned = m; tuned.page.count = 500
        #expect(store.applyRemote(json: try JSONEncoder().encode(tuned)))
        #expect(store.current.page.count == 500)
    }

    @Test func theFlyerStartsAtTheCardsAsteriskHeightOver44() {
        let t = SupernovaTransition()
        t.report(.member, rect: CGRect(x: 16, y: 120, width: 370, height: 170), asterisk: CGPoint(x: 90, y: 135), starHeight: 13.2)
        t.open(.member, fromSource: true)
        #expect(t.kind == .member && t.isShared)
        t.wordmarkMeasured(CGRect(x: 330, y: 124, width: 20, height: 40))
        let f = t.frame(at: t.t0)
        #expect(abs(f.flyer!.scale - 13.2 / 44) < 1e-9)
        #expect(f.maskRadius == 14 && f.groups.count == 4 && f.bannerText.count == 3)
        #expect(t.sourceAsteriskHidden(.member) && !t.sourceAsteriskHidden(.paywall), "only the card's asterisk is swapped")
        #expect(t.sourceText(.paywall, at: t.t0).count == 4, "the free banner is untouched")
    }

    @Test func theCloseMorphsToTheCardsGradientNotTheBanners() {
        let g = SupernovaTransitionGeometry(bannerRect: CGRect(x: 16, y: 120, width: 370, height: 170), bannerAsterisk: CGPoint(x: 90, y: 135),
                                            wordmarkAsterisk: CGPoint(x: 340, y: 120), screen: CGRect(x: 0, y: 0, width: 402, height: 874), startScale: 0.3)
        let f = SupernovaTransitionMath.closing(t: 560, g: g, config: m.transition, morph: .card)
        #expect(f.morph?.style == .card && f.maskRect == g.bannerRect && f.maskRadius == 14)
        #expect(f.flyer?.center == g.bannerAsterisk && abs(f.flyer!.scale - 0.3) < 1e-9)
    }

    // MARK: Impact numbers

    @Test func countersAddUp() {
        let name = "impact-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!; d.removePersistentDomain(forName: name)
        SupernovaImpact.record(suggestedWeightsUsed: 4, prsOnSuggestedWeight: 1, defaults: d)
        SupernovaImpact.record(suggestedWeightsUsed: 2, prsOnSuggestedWeight: 0, defaults: d)
        #expect(SupernovaImpact.suggestedWeightsUsed(d) == 6 && SupernovaImpact.prsOnSuggestedWeight(d) == 1)
    }

    @Test func aGroupLagsUnderSixtyPercentOfTheAverage() {
        #expect(SupernovaImpact.laggingMuscles(setsByGroup: [:]) == 0)
        #expect(SupernovaImpact.laggingMuscles(setsByGroup: ["Back": 10, "Chest": 10, "Legs": 10, "Shoulders": 10, "Arms": 10]) == 0)
        #expect(SupernovaImpact.laggingMuscles(setsByGroup: ["Back": 20, "Chest": 20, "Legs": 2, "Shoulders": 20, "Arms": 3]) == 2)
    }

    @Test func recapsCountWeeksTheMemberTrained() {
        var cal = WeeklyRecapStats.isoMonday; cal.timeZone = TimeZone(identifier: "UTC")!
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(timeZone: cal.timeZone, year: y, month: m, day: d, hour: 12))! }
        let since = day(2026, 3, 2)   // a Monday
        let workouts = [day(2026, 3, 3), day(2026, 3, 5), day(2026, 3, 17), day(2026, 3, 31)]
        // Weeks of 2 Mar, 9 Mar, 16 Mar, 23 Mar, 30 Mar; only complete weeks by 5 Apr count: trained in 2, 16 and 30 Mar.
        #expect(SupernovaImpact.weeklyRecapsSent(since: since, workoutDates: workouts, now: day(2026, 4, 6), calendar: cal) == 3)
        #expect(SupernovaImpact.weeklyRecapsSent(since: since, workoutDates: workouts, now: day(2026, 3, 4), calendar: cal) == 0, "no week has finished yet")
    }
}
