import SwiftUI

/// 6b — friend profile: stats, 30-day body map, this week's training days.
struct FriendProfileView: View {
    @Environment(\.weightUnit) private var unit
    let initialProfile: FirestoreUserProfile
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var profile: FirestoreUserProfile
    @State private var isFollowing: Bool
    @State private var recentPosts: [WorkoutFeedItem] = []
    @State private var isLoading = true

    init(profile: FirestoreUserProfile, viewModel: SocialViewModel) {
        self.initialProfile = profile
        self.viewModel = viewModel
        _profile = State(initialValue: profile)
        _isFollowing = State(initialValue: viewModel.friends.contains { $0.uid == profile.uid })
    }

    /// Real weighted set counts across this friend's recent posted sessions (primary
    /// muscles full credit, secondary half — `muscleSetCounts()`; only posted workouts are
    /// visible to us, not their full local history, so "30-day" is really "30-day posted").
    private var thirtyDayMuscleCounts: [MuscleGroup: Double] {
        recentPosts.flatMap(\.exercises).muscleSetCounts()
    }
    private var perMuscleSetCounts: [(label: String, count: Int)] {
        thirtyDayMuscleCounts.sorted { $0.value > $1.value }
            .prefix(6)
            .map { ($0.key.displayName.uppercased(), Int($0.value.rounded())) }
    }

    /// This week's 7 days — a day counts as "trained" if a post landed on it.
    private var last7Days: [(date: Date, post: WorkoutFeedItem?)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let post = recentPosts.first { cal.isDate($0.date, inSameDayAs: day) }
            return (day, post)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        Avatar(initial: profile.displayName, size: 60)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("@\(profile.username)").font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                            Text(profile.displayName).font(.archivo(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        }
                        Spacer()
                        Button {
                            let wasFollowing = isFollowing
                            isFollowing.toggle()
                            Task {
                                if wasFollowing {
                                    await viewModel.unfollow(uid: profile.uid)
                                } else {
                                    await viewModel.sendFriendRequest(to: profile.uid)
                                }
                            }
                        } label: {
                            Text(isFollowing ? "FOLLOWING" : "FOLLOW")
                                .font(Font.spaceMono(9, weight: .bold)).tracking(1.2)
                                .foregroundStyle(isFollowing ? Color.inkMuted : .white)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(isFollowing ? Color.clear : Color.pumpAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isFollowing ? Color.ruleStrong : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16).padding(.bottom, 14)

                    HStack(spacing: 6) {
                        KPIBlock(label: "Streak", value: "\(profile.currentStreak)D")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "This Wk", value: "\(last7Days.filter { $0.post != nil }.count)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "Volume", value: volumeLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        KPIBlock(label: "PRs", value: "\(recentPosts.reduce(0) { $0 + $1.prCount })", valueColor: .prGold)
                            .shadow(color: Color.prGold.opacity(0.4), radius: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 14)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    HStack(alignment: .top, spacing: 16) {
                        BodyHeat(intensities: BodyHeat.Intensities(exercises: recentPosts.flatMap(\.exercises)))
                            .frame(width: 75, height: 120)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(perMuscleSetCounts, id: \.label) { m in
                                HStack {
                                    Text(m.label).font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                                    Spacer()
                                    Text("\(m.count)").font(Font.spaceMono(11, weight: .bold)).foregroundStyle(Color.inkPrimary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    SectionLabel(title: "This Week", meta: "\(last7Days.filter { $0.post != nil }.count) Of 7 Days")
                        .padding(.top, 16).padding(.bottom, 6)

                    ForEach(last7Days, id: \.date) { day in
                        dayRow(day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .task {
            if let fetched = try? await viewModel.firestoreService.fetchUserProfile(uid: profile.uid) {
                profile = fetched
            }
            recentPosts = (try? await viewModel.firestoreService.fetchFeed(friendUids: [profile.uid])) ?? []
            isLoading = false
        }
    }

    private var volumeLabel: String {
        let total = recentPosts.flatMap(\.exercises).flatMap(\.sets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return unit.compactVolume(total)   // feed weights are kg
    }

    private func dayRow(_ day: (date: Date, post: WorkoutFeedItem?)) -> some View {
        HStack {
            Text(day.date.formatted(.dateTime.weekday(.wide))).font(.archivo(15, weight: .medium)).foregroundStyle(Color.inkPrimary)
            Spacer()
            if let post = day.post {
                Text("\(post.exercises.reduce(0) { $0 + $1.sets.count }) SETS").font(Font.spaceMono(10)).foregroundStyle(Color.inkMuted)
                Text("›").font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
            } else {
                Text("—").font(Font.spaceMono(10)).foregroundStyle(Color.inkFaint)
            }
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}
