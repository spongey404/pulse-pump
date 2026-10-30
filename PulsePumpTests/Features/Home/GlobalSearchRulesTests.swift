import Testing
import Foundation
@testable import PulsePump

struct GlobalSearchRulesTests {
    @Test func everythingShowsThreeRowsAndAFilterShowsAll() {
        #expect(GlobalSearchRules.rowLimit(for: .all) == 3)
        #expect(GlobalSearchRules.rowLimit(for: .exercises) == 20)
    }

    @Test func seeAllOnlyAppearsWhenRowsAreHidden() {
        #expect(GlobalSearchRules.showsSeeAll(hits: 4, category: .all))
        #expect(!GlobalSearchRules.showsSeeAll(hits: 3, category: .all))
        #expect(!GlobalSearchRules.showsSeeAll(hits: 15, category: .exercises))
    }

    @Test func sectionTitlesCarryTheCount() {
        #expect(GlobalSearchRules.sectionTitle("Exercises", hits: 7) == "EXERCISES · 7")
    }

    @Test func recentsAreNewestFirstWithoutDuplicates() {
        var r = SearchRecents()
        r.add("bench"); r.add("push day"); r.add("  Bench ")
        #expect(r.items == ["Bench", "push day"])
        r.add("   ")
        #expect(r.items.count == 2, "blank searches aren't kept")
    }

    @Test func recentsAreCappedAndCanBeRemovedOrCleared() {
        var r = SearchRecents()
        for i in 0..<12 { r.add("term \(i)") }
        #expect(r.items.count == SearchRecents.cap)
        #expect(r.items.first == "term 11")
        r.remove("term 11")
        #expect(r.items.first == "term 10")
        r.clear()
        #expect(r.items.isEmpty)
    }

    @Test func recentsSurviveARelaunch() {
        let defaults = UserDefaults(suiteName: "GlobalSearchRulesTests")!
        defaults.removePersistentDomain(forName: "GlobalSearchRulesTests")
        var r = SearchRecents(); r.add("rdl"); r.save(defaults)
        #expect(SearchRecents.load(defaults).items == ["rdl"])
    }
}
