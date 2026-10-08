import Testing
import Foundation
import SwiftData
@testable import PulsePump

/// Invariant under test: everything stored is kg; `UnitPreference` only changes display and input.
@MainActor
struct UnitsTests {

    // MARK: Conversion

    @Test func kgIsIdentity() {
        #expect(UnitPreference.kg.display(82.5) == 82.5)
        #expect(UnitPreference.kg.kg(fromDisplay: 82.5) == 82.5)
    }

    @Test func knownConversions() {
        #expect(abs(UnitPreference.lbs.display(100) - 220.462) < 0.001)
        #expect(abs(UnitPreference.lbs.kg(fromDisplay: 225) - 102.0582) < 0.001)
        #expect(abs(UnitPreference.lbs.kg(fromDisplay: 45) - 20.4117) < 0.001)
    }

    @Test func roundTripKgLbKgWithinTolerance() {
        for kg in [0.0, 0.25, 1.25, 2.5, 20, 82.5, 100, 227.5, 450, 0.001] {
            let back = UnitPreference.lbs.kg(fromDisplay: UnitPreference.lbs.display(kg))
            #expect(abs(back - kg) < 1e-9)
        }
    }

    @Test func roundTripLbKgLbRecoversTypedValue() {
        // What a lbs user types is shown back to them exactly, even though it is stored as kg.
        for lb in [45.0, 95, 135, 185, 225.5, 315, 405, 2.5] {
            let kg = UnitPreference.lbs.kg(fromDisplay: lb)
            #expect(UnitPreference.lbs.number(kg) == UnitPreference.trim(lb))
            #expect(UnitPreference.lbs.inputText(kg) == UnitPreference.trim(lb))
        }
    }

    // MARK: Rounding + formatting

    @Test func lbDisplaySnapsToHalfPounds() {
        #expect(UnitPreference.lbs.roundedDisplay(100) == 220.5)   // 220.46 lb
        #expect(UnitPreference.lbs.number(100) == "220.5")
        #expect(UnitPreference.lbs.number(82.5) == "182")          // 181.88 lb
        #expect(UnitPreference.lbs.number(0.4) == "1")             // 0.88 lb
    }

    @Test func kgDisplayKeepsTypedPrecision() {
        #expect(UnitPreference.kg.number(82.5) == "82.5")
        #expect(UnitPreference.kg.number(82.25) == "82.25")
        #expect(UnitPreference.kg.number(80) == "80")
        #expect(UnitPreference.kg.number(0) == "0")
    }

    @Test func formattedStringsCarryUnitLabel() {
        #expect(UnitPreference.kg.format(82.5) == "82.5 KG")
        #expect(UnitPreference.lbs.format(UnitPreference.lbs.kg(fromDisplay: 182)) == "182 LB")
        #expect(UnitPreference.kg.formatTight(100) == "100KG")
        #expect(UnitPreference.kg.formatDelta(2.5) == "+2.5 KG")
        #expect(UnitPreference.kg.formatDelta(-2.5) == "-2.5 KG")
        #expect(UnitPreference.lbs.formatDelta(2.5) == "+5.5 LB")      // 5.51 lb
        #expect(UnitPreference.kg.formatVolume(12340) == "12,340 KG")
        #expect(UnitPreference.lbs.formatVolume(1000) == "2,205 LB")
        #expect(UnitPreference.kg.compactVolume(13400) == "13.4K")
        #expect(UnitPreference.kg.compactVolume(850) == "850")
    }

    @Test func parseAcceptsCommaAndRejectsGarbage() {
        #expect(UnitPreference.kg.parseKg("82,5") == 82.5)
        #expect(UnitPreference.kg.parseKg(" 100 ") == 100)
        #expect(UnitPreference.kg.parseKg("") == nil)
        #expect(UnitPreference.kg.parseKg("abc") == nil)
        #expect(abs((UnitPreference.lbs.parseKg("225") ?? 0) - 102.0582) < 0.001)
    }

    @Test func edgeValues() {
        #expect(UnitPreference.lbs.display(0) == 0)
        #expect(UnitPreference.lbs.number(0) == "0")
        #expect(UnitPreference.lbs.format(0) == "0 LB")
        #expect(UnitPreference.lbs.number(1000) == "2204.5")
    }

    // MARK: Kg-string field mapping (logger text fields)

    @Test func kgStringFieldMappingIsIdentityForKg() {
        #expect(UnitPreference.kg.displayText(kgString: "82.5") == "82.5")
        #expect(UnitPreference.kg.kgString(displayText: "82.") == "82.")   // never reformats mid-typing
        #expect(UnitPreference.kg.kgString(displayText: "") == "")
    }

    @Test func kgStringFieldMappingRoundTripsForLbs() {
        let kgStr = UnitPreference.lbs.kgString(displayText: "225")
        #expect(Double(kgStr)! > 102.05 && Double(kgStr)! < 102.07)
        #expect(UnitPreference.lbs.displayText(kgString: kgStr) == "225")
        #expect(UnitPreference.lbs.displayText(kgString: "") == "")
        #expect(UnitPreference.lbs.kgString(displayText: "") == "")
        #expect(UnitPreference.lbs.kgString(displayText: "22.5x") == "22.5x")   // unparsable passes through
    }

    // MARK: Height

    @Test func heightConversions() {
        #expect(abs(UnitPreference.cm(feet: 5, inches: 11) - 180.34) < 0.01)
        let ftIn = UnitPreference.feetInches(fromCm: 180.34)
        #expect(ftIn.feet == 5 && ftIn.inches == 11)
        #expect(UnitPreference.kg.formatHeight(cm: 180.34) == "180 CM")
        #expect(UnitPreference.lbs.formatHeight(cm: 180.34) == "5'11\"")
    }

    // MARK: Plates

    @Test func lbPlateSetLoadsRealLbPlates() {
        // 225 lb on a 45 lb bar = 90 lb per side = 2 x 45.
        let u = UnitPreference.lbs
        let load = PlateMath.load(targetKg: u.kg(fromDisplay: 225), barKg: u.olympicBarKg,
                                  platesKg: u.defaultPlatesKg, unit: u)
        #expect(load.plates.map(\.display) == [45, 45])
        #expect(load.remainder == 0)
    }

    @Test func lbPlateLoadWithSmallPlatesAndRemainder() {
        let u = UnitPreference.lbs
        // 185 lb: 70 per side = 45 + 25.
        let a = PlateMath.load(targetKg: u.kg(fromDisplay: 185), barKg: u.olympicBarKg, platesKg: u.defaultPlatesKg, unit: u)
        #expect(a.plates.map(\.display) == [45, 25])
        // 137 lb: 46 per side = 45 + 1 left over.
        let b = PlateMath.load(targetKg: u.kg(fromDisplay: 137), barKg: u.olympicBarKg, platesKg: u.defaultPlatesKg, unit: u)
        #expect(b.plates.map(\.display) == [45])
        #expect(abs(b.remainder - 1) < 0.01)
    }

    @Test func kgPlateLoad() {
        let u = UnitPreference.kg
        let load = PlateMath.load(targetKg: 100, barKg: 20, platesKg: u.defaultPlatesKg, unit: u)
        #expect(load.plates.map(\.display) == [25, 15])
        #expect(load.remainder == 0)
        #expect(PlateMath.load(targetKg: 20, barKg: 20, platesKg: u.defaultPlatesKg, unit: u).plates.isEmpty)
        let odd = PlateMath.load(targetKg: 61, barKg: 20, platesKg: u.defaultPlatesKg, unit: u)   // 20.5 per side
        #expect(odd.plates.map(\.display) == [20])
        #expect(abs(odd.remainder - 0.5) < 0.001)
    }

    @Test func plateTiersColourLbPlatesLikeTheirKgTwins() {
        #expect(PlateMath.tier(forKg: 25) == .red)
        #expect(PlateMath.tier(forKg: 45 * UnitPreference.kgPerLb) == .blue)   // 45 lb ~ 20 kg
        #expect(PlateMath.tier(forKg: 20) == .blue)
        #expect(PlateMath.tier(forKg: 2.5 * UnitPreference.kgPerLb) == .light)
    }

    // MARK: Stored values are untouched by the preference

    @Test func changingPreferenceNeverMutatesStoredKg() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let user = User(name: "T", weight: 82.5, height: 180, age: 30, unitPreference: .kg)
        ctx.insert(user)
        let set = SetLog(order: 0, weight: 100, reps: 5)
        let profile = EquipmentProfile(name: "Home")
        ctx.insert(set); ctx.insert(profile)
        let platesBefore = profile.availablePlates
        let barBefore = profile.barTypes.map(\.weightKg)

        user.unitPreference = .lbs
        try ctx.save()
        user.unitPreference = .kg
        user.unitPreference = .lbs

        #expect(user.weight == 82.5)
        #expect(user.height == 180)
        #expect(set.weight == 100)
        #expect(profile.availablePlates == platesBefore)
        #expect(profile.barTypes.map(\.weightKg) == barBefore)
        // ...while the display follows the preference.
        #expect(user.unitPreference.format(user.weight) == "182 LB")   // 181.88 -> 182.0 (nearest 0.5)
        #expect(user.unitPreference.number(set.weight) == "220.5")
    }

    @Test func lbsOnboardingInputIsStoredAsKgOnce() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let vm = OnboardingViewModel()
        vm.setUnit(.lbs)
        vm.weightText = "180"
        vm.heightFeet = "5"; vm.heightInches = "11"
        #expect(vm.useImperialHeight)
        vm.completeOnboarding(modelContext: ctx)
        let user = try #require(try ctx.fetch(FetchDescriptor<User>()).first)
        #expect(abs(user.weight - 81.6466) < 0.001)           // 180 lb, not 180 kg and not converted twice
        #expect(abs(user.height - 180.34) < 0.01)
        #expect(user.unitPreference == .lbs)
        #expect(user.unitPreference.number(user.weight) == "180")
    }

    @Test func switchingOnboardingUnitKeepsTheSameBodyWeight() {
        let vm = OnboardingViewModel()
        vm.weightText = "80"
        vm.setUnit(.lbs)
        #expect(vm.weightText == "176.5")                     // 176.37 lb snapped to 0.5
        #expect(vm.unitPreference == .lbs)
    }

    // MARK: Challenges, snapshot, import/export

    @Test func challengeScoresConvertOnlyForWeightMetrics() {
        #expect(ChallengeMetric.totalVolume.formatScore(1000, .lbs) == "2205")
        #expect(ChallengeMetric.totalVolume.formatScore(1000, .kg) == "1000")
        #expect(ChallengeMetric.mostReps.formatScore(1000, .lbs) == "1000")
        #expect(ChallengeMetric.totalVolume.unitLabel(.lbs) == "LB LIFTED")
        #expect(ChallengeMetric.mostReps.unitLabel(.lbs) == "REPS")
    }

    @Test func snapshotLabelsAndConvertsFromItsUnit() {
        var snap = PumpWidgetSnapshot()
        snap.hasData = true
        snap.bodyweight = 80
        snap.weightUnit = .lbs
        let piece = PumpWidgetPiece(id: "t", type: .num, metric: "bw", x: 0, y: 0, w: 1, h: 1)
        let m = snap.metric(for: piece)
        #expect(m.u == "LB")
        #expect(m.v == "176.4")   // widget tiles show one decimal
        snap.weightUnit = nil
        #expect(snap.metric(for: piece).u == "KG")
        #expect(snap.metric(for: piece).v == "80")
    }

    @Test func importDetectsUnitFromHeaders() {
        #expect(DataImportService.detectUnit(headers: ["title", "weight_kg"]) == .kg)
        #expect(DataImportService.detectUnit(headers: ["title", "weight_lbs"]) == .lbs)
        #expect(DataImportService.detectUnit(headers: ["Weight (lbs)"]) == .lbs)
        #expect(DataImportService.detectUnit(headers: ["Date", "Weight"]) == nil)
    }

    @Test func strongImportConvertsLbsToKg() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let user = User(name: "T", unitPreference: .kg)
        ctx.insert(user)
        let csv = "Date,Workout Name,Exercise Name,Set Order,Weight,Reps\n2026-01-05 10:00:00,Push,Bench Press,1,225,5\n"
        let n = try DataImportService.importStrongCSV(csv, modelContext: ctx, user: user, sourceUnit: .lbs)
        #expect(n == 1)
        let sets = try ctx.fetch(FetchDescriptor<SetLog>())
        #expect(sets.count == 1)
        #expect(abs(sets[0].weight - 102.0582) < 0.001)
    }

    @Test func hevyImportHonoursHeaderUnit() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let user = User(name: "T", unitPreference: .lbs)
        ctx.insert(user)
        let kgCSV = "title,start_time,end_time,description,exercise_title,superset_id,set_index,set_type,weight_kg,reps\nPush,2026-01-05 10:00:00,,,Bench Press,,0,normal,100,5\n"
        _ = try DataImportService.importHevyCSV(kgCSV, modelContext: ctx, user: user, sourceUnit: .lbs)
        #expect(try ctx.fetch(FetchDescriptor<SetLog>()).first?.weight == 100)   // header says kg: not re-converted
    }

    @Test func exportsAreKgAndSaySo() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let user = User(name: "T", unitPreference: .lbs)
        ctx.insert(user)
        let w = Workout(isDraft: false); w.user = user; ctx.insert(w)
        let log = ExerciseLog(order: 0, notes: ""); log.workout = w; ctx.insert(log)
        let s = SetLog(order: 0, weight: 100, reps: 5); s.exerciseLog = log; ctx.insert(s)
        let csv = try DataExportService.generateCSV(from: ctx)
        #expect(csv.hasPrefix("Date,Exercise,Set,Weight,Unit,"))
        #expect(csv.contains(",100.0,kg,5,"))
        let json = String(decoding: try DataExportService.exportWorkouts(from: ctx), as: UTF8.self)
        #expect(json.contains("\"weightUnit\" : \"kg\""))
    }
}
