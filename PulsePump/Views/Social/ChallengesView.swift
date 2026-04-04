import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Query(sort: \Challenge.startDate, order: .reverse) private var challenges: [Challenge]

    var body: some View {
        List {
            if challenges.isEmpty {
                ContentUnavailableView(
                    "No Challenges",
                    systemImage: "trophy",
                    description: Text("Challenges are a Pulse+ feature. Create or join challenges to compete with friends.")
                )
            } else {
                ForEach(challenges) { challenge in
                    ChallengeRowView(challenge: challenge)
                }
            }
        }
        .listStyle(.plain)
        // TODO: Pulse+ gate — only Pulse+ users can create challenges
    }
}

struct ChallengeRowView: View {
    let challenge: Challenge

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(challenge.name)
                    .font(.body.weight(.medium))
                Spacer()
                if challenge.isActive {
                    Text("Active")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.pumpPrimary.opacity(0.15))
                        .foregroundStyle(Color.pumpPrimary)
                        .clipShape(Capsule())
                }
            }

            Text(challenge.metric.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(challenge.participantIds.count) participants")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(challenge.endDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Leaderboard preview
            if !challenge.leaderboard.isEmpty {
                VStack(spacing: 4) {
                    ForEach(challenge.leaderboard.prefix(3)) { entry in
                        HStack {
                            Text("#\(entry.rank)")
                                .font(.caption.weight(.semibold))
                                .frame(width: 24, alignment: .leading)
                            Text(entry.username)
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f", entry.score))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
