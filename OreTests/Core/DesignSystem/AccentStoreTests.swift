import Testing
import SwiftUI
@testable import Ore

@Suite(.serialized)
@MainActor
struct AccentStoreTests {
    private func store(member: Bool, account: String? = nil, defaults: UserDefaults? = nil) -> (AccentStore, UserDefaults) {
        let name = "accent-tests-\(UUID().uuidString)"
        let d = defaults ?? UserDefaults(suiteName: name)!
        if defaults == nil { d.removePersistentDomain(forName: name) }
        d.set(member, forKey: SupernovaService.subscribedMirrorKey)
        return (AccentStore(defaults: d, account: account), d)
    }
    private func pick(_ hex: String) -> AccentPick {
        let c = AccentMath.hsl(fromHex: hex)!
        return AccentPick(h: c.h, s: c.s, l: c.l, hex: hex)
    }

    @Test func everyoneStartsOnOresAccent() {
        let (s, _) = store(member: false)
        #expect(s.picked.hexString == "#3DB8FF" && s.usesOreAccent, "drawn with the catalogue's Ore blue, not the swatch's hex")
        #expect(s.swatches.count == 11 && s.swatches.first?.name == "SKY")
    }

    @Test func aFreeUserKeepsOresAccentEvenWithAPick() {
        let (s, _) = store(member: false)
        s.set(pick("#8C0099"))
        #expect(s.active.hexString == "#3DB8FF" && s.usesOreAccent, "a lapsed membership goes back to Ore's accent")
        #expect(s.picked.hexString == "#8C0099", "…without losing what they picked")
    }

    @Test func stardustEnabledAreAMembersSettingPerAccountAndOnByDefault() {
        let (s, d) = store(member: true, account: "a")
        #expect(s.stardustEnabled, "on by default for a member")
        s.setStardustEnabled(false)
        #expect(!s.stardustEnabled)
        #expect(!AccentStore(defaults: d, account: "a").stardustEnabled, "kept for the account")
        #expect(AccentStore(defaults: d, account: "b").stardustEnabled, "another account has its own (on)")
        let lapsed = store(member: false, account: "b", defaults: d)
        #expect(!lapsed.0.stardustEnabled, "a free user never gets it, even with the setting on")
    }

    @Test func theSettingSavedUnderTheOldNameIsKeptAndRewritten() throws {
        let (first, d) = store(member: true, account: "old")
        first.setStardustEnabled(false)
        first.flush()
        // Rewrite the saved blob the way the pre-rename build stored it: `glitterButtons`, no `stardustEnabled`.
        let key = "\(AccentStore.defaultsPrefix).old"
        let blob = try #require(d.data(forKey: key))
        var json = try #require(JSONSerialization.jsonObject(with: blob) as? [String: Any])
        json["glitterButtons"] = json.removeValue(forKey: "stardustEnabled")
        d.set(try JSONSerialization.data(withJSONObject: json), forKey: key)

        let s = AccentStore(defaults: d, account: "old")
        #expect(!s.stardustEnabled, "a member who had turned it off keeps that choice")
        let after = try #require(d.data(forKey: key))
        let rewritten = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
        #expect(rewritten["glitterButtons"] == nil && rewritten["stardustEnabled"] as? Bool == false, "old key dropped, new key written")
    }

    @Test func aMemberGetsTheirPickAndItIsRemembered() {
        let (s, d) = store(member: true)
        s.set(pick("#FD4A9F"))
        #expect(s.active.hexString == "#FD4A9F" && !s.usesOreAccent)
        s.flush()
        #expect(AccentStore(defaults: d).active.hexString == "#FD4A9F", "survives a relaunch")
    }

    @Test func buyingOrLosingSupernovaSwitchesTheAccent() {
        let (s, d) = store(member: false)
        s.set(pick("#FD4A9F"))
        #expect(s.usesOreAccent)
        d.set(true, forKey: SupernovaService.subscribedMirrorKey); s.refreshMembership()
        #expect(s.active.hexString == "#FD4A9F" && !s.usesOreAccent)
        d.set(false, forKey: SupernovaService.subscribedMirrorKey); s.refreshMembership()
        #expect(s.usesOreAccent)
    }

    @Test func eachAccountKeepsItsOwnPickAndRecentRow() {
        let (s, d) = store(member: true, account: "alice")
        s.set(pick("#009945")); s.commitColour()
        s.setAccount("bob")
        #expect(s.picked.hexString == "#3DB8FF" && s.swatches.first?.hex == "#3DB8FF", "a new account starts fresh")
        s.set(pick("#FCC01D"))
        s.setAccount("alice")   // saves bob's colour on the way out
        #expect(s.picked.hexString == "#009945" && s.swatches.first?.hex == "#009945", "alice's pick and her recent row come back")
        #expect(AccentStore(defaults: d, account: "bob").picked.hexString == "#FCC01D")
    }

    @Test func leavingThePageAddsTheColourToTheFrontOfTheRecentRow() {
        let (s, _) = store(member: true)
        s.set(AccentPick(h: 20, s: 80, l: 50, hex: nil))   // a slider colour, not in the row
        let custom = s.picked.hexString
        s.commitColour()
        #expect(s.swatches.count == 11 && s.swatches[0].hex == custom && s.swatches[0].name == "RECENT")
        #expect(s.swatches.last?.hex != "#FFFFFF", "the last preset dropped off")
        s.commitColour()
        #expect(s.swatches.filter { $0.hex == custom }.count == 1, "committing twice doesn't duplicate")
        s.set(pick("#00EBEB")); s.commitColour()
        #expect(s.swatches[0].hex == "#00EBEB" && s.swatches.filter { $0.hex == "#00EBEB" }.count == 1, "a colour already in the row moves to the front")
    }

    @Test func theStardustFollowsThePick() {
        let (s, _) = store(member: true)
        s.set(pick("#FD4A9F"))
        #expect(s.starPalette.accent == StarRGBA(css: "#FD4A9F"), "the middle stop is the exact picked hex")
        let (free, _) = store(member: false)
        free.set(pick("#FD4A9F"))
        #expect(free.starPalette.accent == StarRGBA(css: "#3DB8FF"))
    }

    @Test func shortSplitNames() {
        #expect(MoreTabView.shortSplit("Push Pull Legs") == "PPL" && MoreTabView.shortSplit("Upper Lower") == "U/L" && MoreTabView.shortSplit("Bro Split") == "BRO SPLIT")
    }
}
