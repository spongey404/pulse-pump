import Foundation

/// A challenge sent from a friend's profile (Ore Feed Post Final §7). Pure rules; the sheet only draws.
/// WHAT COUNTS: most volume, most sessions, or beat a PR. Only sessions logged after the friend accepts count.
struct DirectChallengeModel: Equatable {
    enum Count: String, CaseIterable { case volume = "Most volume", sessions = "Most sessions", beatPR = "Beat a PR" }
    enum Beat: String, CaseIterable { case own, theirs }
    enum Length: String, CaseIterable {
        case week = "1 WEEK", twoWeeks = "2 WEEKS", month = "1 MONTH"
        var days: Int { self == .week ? 7 : (self == .twoWeeks ? 14 : 30) }
    }

    var count: Count = .volume
    var beat: Beat = .own
    var lifts: [String] = []
    var increment: Double = 2.5
    var length: Length = .week

    static let increments: [Double] = [2.5, 5, 10]

    /// Lift chips are multi-select, so toggling adds or removes.
    mutating func toggle(_ lift: String) {
        if let i = lifts.firstIndex(of: lift) { lifts.remove(at: i) } else { lifts.append(lift) }
    }

    /// SEND is disabled until a lift is picked (for Beat a PR).
    var canSend: Bool { count != .beatPR || !lifts.isEmpty }

    /// Your strongest lifts first (heaviest best set), each with its PR, so the chips are ordered by what you are best at.
    static func strongest(_ best: [String: Double], limit: Int = 8) -> [(name: String, kg: Double)] {
        best.filter { $0.value > 0 }.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(limit).map { ($0.key, $0.value) }
    }

    /// What you have to lift. Own PR: your best + the step. Their PR: more than their best (a new PR even if you are already ahead).
    func target(for lift: String, mine: [String: Double], theirs: [String: Double]) -> Double? {
        switch beat {
        case .own: return mine[lift].map { $0 + increment }
        case .theirs: return theirs[lift].map { $0 }
        }
    }

    /// The row of the LIFT / YOU / THEM table; the higher number is flagged so the screen can colour it green.
    struct VsRow: Equatable { var lift: String; var you: Double?; var them: Double?; var youHigher: Bool; var themHigher: Bool }
    func vsRows(mine: [String: Double], theirs: [String: Double]) -> [VsRow] {
        lifts.map { l in
            let y = mine[l], t = theirs[l]
            return VsRow(lift: l, you: y, them: t, youHigher: (y ?? 0) > (t ?? 0), themHigher: (t ?? 0) > (y ?? 0))
        }
    }

    static let theirPRRule = "Each of you has to lift more than the other's best. If you're already ahead on a lift, you need a new PR to keep it."

    func draft(me: String, them: String, now: Date = Date(), calendar: Calendar = .current) -> ChallengeDraft {
        let end = calendar.date(byAdding: .day, value: length.days, to: now) ?? now.addingTimeInterval(Double(length.days) * 86_400)
        let metric: ChallengeMetric = count == .volume ? .totalVolume : (count == .sessions ? .sessionsLogged : .heaviestLift)
        return ChallengeDraft(name: "\(me) vs \(them)", metric: metric, exerciseName: count == .beatPR ? lifts.first : nil, startAt: now, endAt: end,
                              visibility: .invite, winCondition: .highest, unit: nil,
                              customLabel: count == .beatPR ? lifts.joined(separator: ", ") : nil)
    }

    /// Profile line while the invite is open: "PENDING · 1 WEEK · WAITING FOR PRIYA".
    static func pendingLine(length: Length, name: String) -> String { "PENDING · \(length.rawValue) · WAITING FOR \(name.uppercased())" }
}

/// Remembers, per friend, the challenge you sent and that nobody has accepted yet, so their profile can say "PENDING…".
enum PendingDirectChallenges {
    private static func key(_ uid: String) -> String { "social.pendingChallenge.\(uid)" }

    static func record(uid: String, length: DirectChallengeModel.Length, challengeId: String, defaults: UserDefaults = .standard) {
        defaults.set(["length": length.rawValue, "id": challengeId], forKey: key(uid))
    }

    static func pending(uid: String, defaults: UserDefaults = .standard) -> (length: DirectChallengeModel.Length, challengeId: String)? {
        guard let d = defaults.dictionary(forKey: key(uid)) as? [String: String], let l = d["length"].flatMap(DirectChallengeModel.Length.init(rawValue:)), let id = d["id"] else { return nil }
        return (l, id)
    }

    static func clear(uid: String, defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key(uid)) }
}
