import SwiftUI
import FirebaseAuth

struct WorkoutCompletionView: View {
    let data: WorkoutCompletionData
    let onDismiss: () -> Void
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var caption = ""
    @State private var showFeedShareConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.pumpPrimary)

                        Text("Workout Complete")
                            .font(.title2.weight(.bold))
                    }
                    .padding(.top, 24)

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        CompletionStatCard(title: "Duration", value: data.formattedDuration, icon: "clock")
                        CompletionStatCard(title: "Calories", value: "\(Int(data.calories))", icon: "flame")
                        CompletionStatCard(title: "Exercises", value: "\(data.exerciseCount)", icon: "figure.strengthtraining.traditional")
                        CompletionStatCard(title: "Sets", value: "\(data.totalSets)", icon: "repeat")
                    }
                    .padding(.horizontal)

                    // PRs — subtle inline highlight, no icons or gamification
                    if data.prCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "medal.fill")
                                .foregroundStyle(.yellow)
                            Text("\(data.prCount) PR\(data.prCount == 1 ? "" : "s")")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.horizontal)
                    }

                    // Improvement
                    if data.totalExercises > 0 {
                        Text("Improved on \(data.improvedCount)/\(data.totalExercises) exercises")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Muscles worked
                    if !data.musclesWorked.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Muscles Worked")
                                .font(.subheadline.weight(.semibold))

                            FlowLayout(spacing: 6) {
                                ForEach(Array(data.musclesWorked).sorted(by: { $0.displayName < $1.displayName }), id: \.self) { muscle in
                                    Text(muscle.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // Caption + share section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Share")
                            .font(.subheadline.weight(.semibold))

                        TextField("Add a caption...", text: $caption, axis: .vertical)
                            .lineLimit(1...3)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        HStack(spacing: 12) {
                            Button {
                                showFeedShareConfirmation = true
                            } label: {
                                Label("Post to Feed", systemImage: "person.2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.pumpPrimary)

                            Button {
                                let card = ShareCardView(cardType: .postWorkout(data))
                                shareImage = renderShareCard(card, size: CGSize(width: 360, height: 220))
                                showShareSheet = shareImage != nil
                            } label: {
                                Label("Share Card", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("Post to Feed", isPresented: $showFeedShareConfirmation) {
                Button("Post") { postToFeed() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(caption.isEmpty ? "Share this workout with your friends?" : "Post with caption: \"\(caption)\"")
            }
        }
    }

    private func postToFeed() {
        let muscles = data.musclesWorked.map(\.displayName)
        Task {
            let feedItem = WorkoutFeedItem(
                userId: Auth.auth().currentUser?.uid ?? "",
                username: Auth.auth().currentUser?.displayName ?? "User",
                templateName: nil,
                exerciseCount: data.exerciseCount,
                durationSeconds: Int(data.duration),
                caloriesBurned: Int(data.calories),
                musclesWorked: muscles,
                prCount: data.prCount,
                improvedCount: data.improvedCount,
                totalExercises: data.totalExercises,
                date: Date(),
                caption: caption
            )
            try? await FirestoreService().shareWorkoutToFeed(feedItem)
        }
    }
}


struct CompletionStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.pumpPrimary)
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flow Layout for muscle tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
