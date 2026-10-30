import Foundation

/// One row of a leaderboard as displayed.
struct LeaderboardRow: Identifiable, Equatable {
    var entry: ChallengeEntry
    /// Competition rank (1, 1, 3): equal scores share a rank.
    var rank: Int
    /// Places gained (positive) or lost (negative) since the last re-rank; 0 = unchanged / new.
    var movement: Int
    var isMe: Bool
    var id: String { entry.uid }
}

/// Scores and ranks are computed by Cloud Functions and stored on `entries`. The client only orders
/// and presents them; it never computes or writes a score.
enum Leaderboard {
    /// Rows in display order. Ranks come from the entries when the functions have ranked them all
    /// (equal scores share a rank, earliest `scoreAt` listed first); otherwise (a brand-new board)
    /// they are derived with the same competition ranking so the board still reads correctly.
    static func rows(from entries: [ChallengeEntry], me: String?) -> [LeaderboardRow] {
        let visible = entries.filter { !$0.hidden || $0.uid == me }
        let ranked = !visible.isEmpty && visible.allSatisfy { $0.rank > 0 }
        if ranked {
            let sorted = visible.sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                return tieBreak($0, $1)
            }
            return sorted.map {
                LeaderboardRow(entry: $0, rank: $0.rank, movement: movement(rank: $0.rank, previousRank: $0.previousRank), isMe: $0.uid == me)
            }
        }
        let sorted = visible.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return tieBreak($0, $1)
        }
        var rows: [LeaderboardRow] = []
        for (index, entry) in sorted.enumerated() {
            let rank = (index > 0 && sorted[index - 1].score == entry.score) ? rows[index - 1].rank : index + 1
            rows.append(LeaderboardRow(entry: entry, rank: rank, movement: 0, isMe: entry.uid == me))
        }
        return rows
    }

    /// Earliest `scoreAt` first, then uid for a stable order.
    private static func tieBreak(_ a: ChallengeEntry, _ b: ChallengeEntry) -> Bool {
        switch (a.scoreAt, b.scoreAt) {
        case let (x?, y?) where x != y: return x < y
        case (nil, _?): return false
        case (_?, nil): return true
        default: return a.uid < b.uid
        }
    }

    /// ▲ n (positive) / ▼ n (negative) / — (0). A missing previous rank means a new entry.
    static func movement(rank: Int, previousRank: Int) -> Int {
        previousRank > 0 && rank > 0 ? previousRank - rank : 0
    }

    /// The score gap to the nearest better-ranked row, for the "TO NEXT" tile.
    static func gapToNext(rows: [LeaderboardRow], mine: LeaderboardRow) -> Double? {
        guard let above = rows.last(where: { $0.rank < mine.rank }) else { return nil }
        return max(0, above.entry.score - mine.entry.score)
    }

    /// Top `top` rows, then the rows within `around` places of mine ("3d" global board). `gapBefore`
    /// marks where a `· · ·` separator belongs.
    static func condensed(rows: [LeaderboardRow], mine: LeaderboardRow?, top: Int = 5, around: Int = 2) -> [(row: LeaderboardRow, gapBefore: Bool)] {
        let kept: [LeaderboardRow]
        if let mine, rows.count > top + 3 {
            kept = rows.filter { $0.rank <= top || abs($0.rank - mine.rank) <= around }
        } else {
            kept = rows
        }
        var lastRank = 0
        return kept.map { row in
            let gap = lastRank != 0 && row.rank - lastRank > 1
            lastRank = row.rank
            return (row, gap)
        }
    }

    static func ordinal(_ n: Int) -> String {
        switch (n % 100, n % 10) {
        case (11, _), (12, _), (13, _): "\(n)TH"
        case (_, 1): "\(n)ST"
        case (_, 2): "\(n)ND"
        case (_, 3): "\(n)RD"
        default: "\(n)TH"
        }
    }
}
