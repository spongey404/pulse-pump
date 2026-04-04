import SwiftUI
import FirebaseAuth

struct ActivityFeedView: View {
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        List {
            if viewModel.isLoadingFeed {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.feedItems.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "person.2",
                    description: Text("Complete workouts to see activity here. Add friends to see their workouts too.")
                )
            } else {
                ForEach(viewModel.feedItems) { item in
                    FeedItemView(item: item, currentUid: viewModel.currentUid ?? "") {
                        Task { await viewModel.toggleLike(postId: item.id) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadFeed()
        }
        .task {
            await viewModel.loadFeed()
        }
    }
}

struct FeedItemView: View {
    let item: WorkoutFeedItem
    let currentUid: String
    let onLike: () -> Void

    private var isLiked: Bool { item.likes.contains(currentUid) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.username)
                        .font(.subheadline.weight(.semibold))
                    Text(item.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Workout summary
            VStack(alignment: .leading, spacing: 6) {
                if let template = item.templateName {
                    Text(template)
                        .font(.body.weight(.medium))
                }

                HStack(spacing: 16) {
                    Label("\(item.exerciseCount) exercises", systemImage: "figure.strengthtraining.traditional")
                    Label("\(item.durationSeconds / 60) min", systemImage: "clock")
                    if item.caloriesBurned > 0 {
                        Label("\(item.caloriesBurned) cal", systemImage: "flame")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Muscles worked tags
                if !item.musclesWorked.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(item.musclesWorked.sorted(), id: \.self) { muscle in
                            Text(muscle)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Interaction bar
            HStack(spacing: 20) {
                Button(action: onLike) {
                    Label(
                        item.likes.isEmpty ? "Like" : "\(item.likes.count)",
                        systemImage: isLiked ? "heart.fill" : "heart"
                    )
                    .font(.caption)
                    .foregroundStyle(isLiked ? Color.pumpPrimary : .secondary)
                }
                Label("\(item.commentCount)", systemImage: "bubble.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}
