#if DEBUG
import Foundation

/// Options for `DevDataService`. Parsed from launch arguments so the same switches work from
/// Xcode (Edit Scheme › Arguments), `xcrun simctl launch`, XCUITest and `bin/createdevdata.sh`:
///
///     -createDevData 1            run the seeder on launch (required)
///     -devDataReset 1             wipe user data first (default: only seed if the store has no user)
///     -devDataScenario busy       busy | lapsed | new-user
///     -devDataWeeks 16            weeks of history (2…52)
///     -devDataSeed 42             RNG seed — same seed, same data
///     -devDataUnits kg            kg | lb (display preference; weights are always stored in kg)
///     -devDataPlus 1              pretend Pulse+ is active
///     -devDataDraft 1             also leave one in-progress workout (Continue card)
///     -devDataSocialFixtures 1    show the demo friends/feed/challenges (default on)
struct DevDataConfig: Equatable {
    enum Scenario: String, CaseIterable {
        /// Five sessions a week for `weeks`, streak alive, one deload week, fresh PRs, a session today.
        case busy
        /// Same history, but nothing in the last 12 days (streak 0, "neglected" muscles).
        case lapsed
        /// Onboarded user, equipment and a split — no workouts (empty states everywhere).
        case newUser = "new-user"
    }

    var scenario: Scenario = .busy
    var weeks = 16
    var seed: UInt64 = 42
    var units: UnitPreference = .kg
    var reset = false
    var plus = false
    var draft = false
    var socialFixtures = true
    /// "Now" for the generated history — injectable so tests are deterministic.
    var now = Date()
    var calendar = Calendar.current

    /// nil unless `-createDevData 1` was passed.
    static func fromLaunchArguments(_ d: UserDefaults = .standard) -> DevDataConfig? {
        guard d.bool(forKey: "createDevData") else { return nil }
        var c = DevDataConfig()
        if let s = d.string(forKey: "devDataScenario"), let v = Scenario(rawValue: s) { c.scenario = v }
        if let w = Int(d.string(forKey: "devDataWeeks") ?? "") { c.weeks = min(max(w, 2), 52) }
        if let s = UInt64(d.string(forKey: "devDataSeed") ?? "") { c.seed = s }
        if let u = d.string(forKey: "devDataUnits") { c.units = (u == "lb" || u == "lbs") ? .lbs : .kg }
        c.reset = d.bool(forKey: "devDataReset")
        c.plus = d.bool(forKey: "devDataPlus")
        c.draft = d.bool(forKey: "devDataDraft")
        if d.object(forKey: "devDataSocialFixtures") != nil { c.socialFixtures = d.bool(forKey: "devDataSocialFixtures") }
        return c
    }
}

/// SplitMix64 — tiny, fast, and identical on every run for a given seed.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// 0 ..< 1
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func jitter(_ amount: Double) -> Double { (unit() * 2 - 1) * amount }
}
#endif
