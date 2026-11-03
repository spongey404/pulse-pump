import SwiftUI

// Pieces the challenge screens share (design "Ore Social Final" 3a, 4a, 6a, 6b, 7b): the page header, avatars, the podium, board
// rows, the pinned "You" card. Each one takes real rows; nothing here invents a number.

extension ChallengeMetric {
    /// The small unit printed after a score ("KG", "REPS"); empty when there is nothing honest to print.
    func scoreSuffix(_ weightUnit: UnitPreference) -> String {
        switch self {
        case .totalVolume, .heaviestLift: weightUnit.label
        case .mostReps: "REPS"
        case .sessionsLogged: "SESSIONS"
        case .longestHold, .custom: ""
        }
    }
}

/// "12 days left" / "5 hours left" / "ends today".
func challengeTimeLeft(_ challenge: SocialChallenge, now: Date = Date()) -> String {
    let cal = Calendar.current
    let days = cal.dateComponents([.day], from: now, to: challenge.endAt).day ?? 0
    if days >= 1 { return "\(days) \(days == 1 ? "day" : "days") left" }
    let hours = max(1, cal.dateComponents([.hour], from: now, to: challenge.endAt).hour ?? 1)
    return "\(hours) \(hours == 1 ? "hour" : "hours") left"
}

/// The design's page header: a small mono label over the 26 pt title, and a row of 36 pt sunken buttons on the right
/// (the back chevron is the last one, as in the design).
struct ChallengeHeader<Actions: View>: View {
    let label: String
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted).lineLimit(2)
                Text(title).font(.archivo(26, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary).lineLimit(2)
                    .accessibilityIdentifier(AX.nav.title(title))
            }
            Spacer(minLength: 8)
            actions()
            if let onBack {
                ChallengeHeaderButton(action: onBack) {
                    Text("‹").font(.archivo(18)).foregroundStyle(Color.inkPrimary)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier(AX.nav.back)
            }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 13)   // 12 + the 1 pt rule (a CSS border takes space)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

extension ChallengeHeader where Actions == EmptyView {
    init(label: String, title: String, onBack: (() -> Void)?) {
        self.init(label: label, title: title, onBack: onBack, actions: { EmptyView() })
    }
}

/// A 36 pt sunken rounded button of the header (min width 36, 12 pt side padding when it carries text).
struct ChallengeHeaderButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(minWidth: 36, minHeight: 36)
                .background(Color.surf2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A header button that holds a mono label ("SKIP", "+ INVITE").
struct ChallengeHeaderTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        ChallengeHeaderButton(action: action) {
            Text(title).font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary).padding(.horizontal, 12)
        }
        .accessibilityLabel(title)
    }
}

/// Rounded-square initial: the viewer is the accent with white ink, everyone else sunken with secondary ink.
struct ChallengeAvatar: View {
    let name: String
    var isMe = false
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: (size * 0.28).rounded(), style: .continuous)
            .fill(isMe ? Color.oreAccent : Color.surf2)
            .frame(width: size, height: size)
            .overlay {
                Text(String((isMe ? "You" : name).prefix(1)).uppercased())
                    .font(.archivo(size * 0.41, weight: .black))
                    .foregroundStyle(isMe ? Color.white : Color.inkSecondary)
            }
            .accessibilityHidden(true)
    }
}

/// A star for ranks 1 to 3 (gold with the PR glow, silver, bronze); nil-free: callers only ask for rank <= 3.
struct RankStar: View {
    let rank: Int
    var size: CGFloat = 15
    var body: some View {
        if rank == 1 { PRStar(size: size) } else { MedalStar(rank: rank, size: size) }
    }
}

/// "3 kg" style value with its small unit: Space Mono bold value, Space Mono 8 muted suffix.
struct ScoreText: View {
    let value: String
    var suffix: String = ""
    var size: CGFloat = 15
    var color: Color = .inkPrimary

    var body: some View {
        (Text(value).font(.spaceMono(size, weight: .bold)).foregroundStyle(color)
         + Text(suffix.isEmpty ? "" : " " + suffix).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted))
    }
}

/// One board row: rank (star for the top three, number after), avatar, name, trailing content. Your row has the accent-row tint
/// and a 2 pt accent edge on the left.
struct ChallengeBoardRow<Trailing: View>: View {
    let row: LeaderboardRow
    var minHeight: CGFloat = 56
    var showStars = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        let name = row.entry.username.isEmpty ? Brand.defaultUserName : row.entry.username
        HStack(spacing: 12) {
            Group {
                if showStars && row.rank <= 3 {
                    RankStar(rank: row.rank, size: 15)
                } else {
                    Text("\(row.rank)").font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkMuted)
                }
            }
            .frame(width: 22)
            ChallengeAvatar(name: name, isMe: row.isMe, size: 32)
            Text(row.isMe ? "You" : name).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: minHeight)
        .padding(.bottom, 1)   // the row's 1 pt rule sits below its min height
        .background(row.isMe ? Color.activeRowBg : Color.clear)
        .overlay(alignment: .leading) { if row.isMe { Rectangle().fill(Color.accentInk).frame(width: 2) } }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

/// The top three as a podium: second, first, third; bar heights 90 / 124 / 68; a star over each avatar.
struct ChallengePodium: View {
    let rows: [LeaderboardRow]
    let metric: ChallengeMetric
    let weightUnit: UnitPreference

    private static let heights: [CGFloat] = [124, 90, 68]   // by place index: 1st, 2nd, 3rd

    var body: some View {
        let top = Array(rows.prefix(3))
        let order = [1, 0, 2].filter { $0 < top.count }
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(order, id: \.self) { i in
                column(top[i], height: Self.heights[i])
            }
        }
        .padding(.horizontal, 16).padding(.top, 22)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func column(_ row: LeaderboardRow, height: CGFloat) -> some View {
        let name = row.entry.username.isEmpty ? Brand.defaultUserName : row.entry.username
        return VStack(spacing: 6) {
            RankStar(rank: min(3, row.rank), size: 18)
            ChallengeAvatar(name: name, isMe: row.isMe, size: 44)
            Text(row.isMe ? "You" : name).font(.archivo(15, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
            VStack(spacing: 0) {
                Text(metric.formatScore(row.entry.score, weightUnit)).font(.spaceMono(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    .minimumScaleFactor(0.6).lineLimit(1)
                let suffix = metric.scoreSuffix(weightUnit)
                if !suffix.isEmpty { Text(suffix).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted) }
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: height, alignment: .top)
            .background(Color.surf, in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The ACTIVITY list under a board: the people who scored most recently, from the entries' own timestamps.
struct ChallengeActivityList: View {
    let rows: [LeaderboardRow]
    let metric: ChallengeMetric
    let weightUnit: UnitPreference

    /// Most recent first, at most five; only entries that have actually scored.
    private var recent: [(row: LeaderboardRow, at: Date)] {
        var items: [(row: LeaderboardRow, at: Date)] = []
        for r in rows where r.entry.score > 0 {
            if let at = r.entry.scoreAt { items.append((row: r, at: at)) }
        }
        items.sort { $0.at > $1.at }
        return Array(items.prefix(5))
    }

    var body: some View {
        if !recent.isEmpty {
            VStack(spacing: 0) {
                SectionLabel(title: "Activity")
                    .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(recent, id: \.row.id) { item in
                        line(item.row, at: item.at)
                    }
                }
                .padding(.top, 1).overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
        }
    }

    private func line(_ row: LeaderboardRow, at: Date) -> some View {
        let name = row.entry.username.isEmpty ? Brand.defaultUserName : row.entry.username
        let suffix = metric.scoreSuffix(weightUnit)
        var text = "Reached \(metric.formatScore(row.entry.score, weightUnit))\(suffix.isEmpty ? "" : " " + suffix.lowercased())."
        if row.movement > 0 { text += " Moved up to \(Leaderboard.ordinal(row.rank).lowercased())." }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.isMe ? "You" : name).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Text(text).font(.archivo(12)).foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 8)
            Text(Self.ago(at)).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 13)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 3600 { return "\(max(1, Int(s / 60)))M" }
        if s < 86_400 { return "\(Int(s / 3600))H" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: now)).day ?? 0
        return days <= 1 ? "YESTERDAY" : "\(days)D"
    }
}

/// "You · 3rd" pinned at the bottom of a board: a card on the elevated surface with the gap to the next place.
struct ChallengePinnedYou: View {
    let mine: LeaderboardRow
    let rows: [LeaderboardRow]
    let metric: ChallengeMetric
    let weightUnit: UnitPreference

    private var detail: String? {
        let suffix = metric.scoreSuffix(weightUnit).lowercased()
        func amount(_ v: Double) -> String { metric.formatScore(v, weightUnit) + (suffix.isEmpty ? "" : " " + suffix) }
        if let above = rows.last(where: { $0.rank < mine.rank }) {
            let name = above.entry.username.isEmpty ? Brand.defaultUserName : above.entry.username
            return "\(amount(max(0, above.entry.score - mine.entry.score))) to pass \(name)"
        }
        if let below = rows.first(where: { $0.rank > mine.rank }) {
            return "\(amount(max(0, mine.entry.score - below.entry.score))) ahead"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            ChallengeAvatar(name: "You", isMe: true, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text("You · \(Leaderboard.ordinal(mine.rank).lowercased())").font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                if let detail { Text(detail).font(.archivo(12)).foregroundStyle(Color.inkMuted) }
            }
            Spacer(minLength: 8)
            Text(metric.formatScore(mine.entry.score, weightUnit)).font(.spaceMono(18, weight: .bold)).foregroundStyle(Color.inkPrimary)
        }
        .padding(14)
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(16)
        .background(Color.canvasBg)
        .accessibilityElement(children: .combine)
    }
}
