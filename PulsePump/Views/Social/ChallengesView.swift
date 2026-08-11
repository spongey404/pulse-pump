import SwiftUI

struct ChallengesView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var showCreateChallenge = false
    @State private var selectedSortField: LeaderboardSortField = .score

    var body: some View {
        List {
            if viewModel.isLoadingChallenges {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.myChallenges.isEmpty && viewModel.activeChallenges.isEmpty {
                ContentUnavailableView(
                    "No Challenges",
                    systemImage: "trophy",
                    description: Text("Create or join challenges to compete with friends.")
                )
            } else {
                if !viewModel.myChallenges.isEmpty {
                    Section("My Challenges") {
                        ForEach(viewModel.myChallenges) { challenge in
                            ChallengeCardView(challenge: challenge, sortField: selectedSortField)
                        }
                    }
                }

                if !viewModel.activeChallenges.isEmpty {
                    Section("Active Challenges") {
                        ForEach(viewModel.activeChallenges) { challenge in
                            VStack(alignment: .leading, spacing: 6) {
                                ChallengeCardView(challenge: challenge, sortField: selectedSortField)

                                if let uid = viewModel.currentUid,
                                   !challenge.participantIds.contains(uid) {
                                    Button("Join Challenge") {
                                        Task { await viewModel.joinChallenge(id: challenge.id, username: "") }
                                    }
                                    .font(.mono(11, weight: .medium))
                                    .foregroundStyle(Color.accentInk)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateChallenge = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("Sort Leaderboard") {
                    Button("By Score") { selectedSortField = .score }
                    Button("By Username") { selectedSortField = .username }
                }
            }
        }
        .sheet(isPresented: $showCreateChallenge) {
            CreateChallengeView(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.loadChallenges()
        }
        .task {
            await viewModel.loadChallenges()
        }
    }
}

enum LeaderboardSortField {
    case score
    case username
}

struct ChallengeCardView: View {
    let challenge: FirestoreChallenge
    let sortField: LeaderboardSortField

    private var sortedLeaderboard: [LeaderboardEntry] {
        switch sortField {
        case .score:
            challenge.leaderboard.sorted { $0.score > $1.score }
        case .username:
            challenge.leaderboard.sorted { $0.username < $1.username }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(challenge.name)
                    .font(.mono(16, weight: .medium))
                Spacer()
                if challenge.isActive {
                    Text("Active")
                        .font(.mono(9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.pumpAccent.opacity(0.15))
                        .foregroundStyle(Color.accentInk)
                        .clipShape(Capsule())
                }
            }

            Text(challenge.metric)
                .font(.mono(11))
                .foregroundStyle(.secondary)

            HStack {
                Text("\(challenge.participantIds.count) participants")
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(challenge.endDate, style: .relative)
                    .font(.mono(11))
                    .foregroundStyle(.secondary)
            }

            if !sortedLeaderboard.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(sortedLeaderboard.prefix(3).enumerated()), id: \.offset) { rank, entry in
                        HStack {
                            Text("#\(rank + 1)")
                                .font(.mono(11, weight: .medium))
                                .frame(width: 24, alignment: .leading)
                            Text(entry.username)
                                .font(.mono(11))
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

struct CreateChallengeView: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var metric: ChallengeMetric = .totalVolume
    @State private var winCondition: ChallengeWinCondition = .highest
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 3600)

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Challenge Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }

                Section("Rules") {
                    Picker("Metric", selection: $metric) {
                        ForEach(ChallengeMetric.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }

                    Picker("Win Condition", selection: $winCondition) {
                        ForEach(ChallengeWinCondition.allCases) { w in
                            Text(w.displayName).tag(w)
                        }
                    }
                }

                Section("Dates") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createChallenge(
                                name: name,
                                description: description,
                                metric: metric,
                                winCondition: winCondition,
                                startDate: startDate,
                                endDate: endDate
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
