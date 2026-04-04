import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @State private var photoItem: PhotosPickerItem?

    private var user: User? { users.first }

    var body: some View {
        List {
            if let user {
                // Avatar + name header
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Group {
                                if let data = user.avatarData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .foregroundStyle(Color(.systemGray3))
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .overlay(
                                Circle().strokeBorder(Color(.systemGray4), lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundStyle(Color.pumpPrimary)
                                    .background(Color(.systemBackground), in: Circle())
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name)
                                .font(.title3.weight(.semibold))
                            if !user.username.isEmpty {
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Stats
                Section("Stats") {
                    let completedWorkouts = user.workouts.filter { !$0.isDraft }
                    LabeledContent("Total Workouts", value: "\(completedWorkouts.count)")
                    LabeledContent("Total Sets", value: "\(completedWorkouts.flatMap(\.exerciseLogs).flatMap(\.sets).count)")

                    let streak = currentStreak(from: completedWorkouts)
                    LabeledContent("Current Streak", value: "\(streak) days")
                }

                // Details
                Section("Details") {
                    LabeledContent("Username", value: user.username.isEmpty ? "Not set" : "@\(user.username)")
                    LabeledContent("Experience", value: user.experienceLevel.displayName)
                    LabeledContent("Units", value: user.unitPreference.displayName)
                }
            } else {
                ContentUnavailableView("No Profile", systemImage: "person.crop.circle")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    user?.avatarData = data
                    user?.updatedAt = Date()
                }
            }
        }
    }

    private func currentStreak(from workouts: [Workout]) -> Int {
        StreakCalculator.currentStreak(from: workouts.map(\.date))
    }
}
