import Testing
import SwiftUI
@testable import Ore

@Suite(.serialized)
@MainActor
struct AccentStoreTests {
    private func store(member: Bool, pick: String? = nil) -> (AccentStore, UserDefaults) {
        let name = "accent-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        d.set(member, forKey: SupernovaService.subscribedMirrorKey)
        if let pick { d.set(pick, forKey: AccentStore.defaultsKey) }
        return (AccentStore(defaults: d), d)
    }

    @Test func everyoneStartsOnOresAccent() {
        let (s, _) = store(member: false)
        #expect(s.active == AccentChoices.ore)
        #expect(AccentChoices.ore.hex == "#1AA7FF")
    }

    @Test func aFreeUserKeepsOresAccentEvenWithAnOldPick() {
        let (s, _) = store(member: false, pick: "violet")
        #expect(s.active == AccentChoices.ore, "a lapsed membership goes back to Ore's accent")
        #expect(s.picked.id == "violet", "…without losing what they picked")
    }

    @Test func aMemberGetsTheirPickAndItIsRemembered() {
        let (s, d) = store(member: true)
        #expect(s.active == AccentChoices.ore)
        let pink = AccentChoices.choice(id: "pink")
        s.select(pink)
        #expect(s.active == pink)
        #expect(d.string(forKey: AccentStore.defaultsKey) == "pink")
        #expect(AccentStore(defaults: d).active == pink, "survives a relaunch")
    }

    @Test func buyingOrLosingSupernovaSwitchesTheAccent() {
        let (s, d) = store(member: false, pick: "coral")
        #expect(s.active == AccentChoices.ore)
        d.set(true, forKey: SupernovaService.subscribedMirrorKey); s.refreshMembership()
        #expect(s.active.id == "coral")
        d.set(false, forKey: SupernovaService.subscribedMirrorKey); s.refreshMembership()
        #expect(s.active == AccentChoices.ore)
    }

    @Test func anUnknownSavedChoiceFallsBackToOre() {
        let (s, _) = store(member: true, pick: "does-not-exist")
        #expect(s.active == AccentChoices.ore)
    }

    @Test func theChoicesAreDistinctAndAmberIsLeftOut() {
        let hexes = AccentChoices.all.map(\.hex)
        #expect(Set(hexes).count == hexes.count)
        #expect(Set(AccentChoices.all.map(\.id)).count == AccentChoices.all.count)
        #expect(AccentChoices.all.first == AccentChoices.ore, "Ore's own blue is the first swatch, so it can always be put back")
        #expect(!hexes.contains("#C9892E") && !hexes.contains("#FFC83D"), "amber is Fuel's signal, gold is Supernova's")
    }

    @Test func theGlitterFollowsTheAccent() {
        let (s, _) = store(member: true, pick: "pink")
        #expect(s.starPalette.accent == AccentChoices.choice(id: "pink").rgba)
        let (free, _) = store(member: false, pick: "pink")
        #expect(free.starPalette.accent == AccentChoices.ore.rgba)
    }

    @Test func shortSplitNames() {
        #expect(MoreTabView.shortSplit("Push Pull Legs") == "PPL" && MoreTabView.shortSplit("Upper Lower") == "U/L" && MoreTabView.shortSplit("Bro Split") == "BRO SPLIT")
    }
}
