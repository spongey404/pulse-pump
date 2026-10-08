import SwiftUI
import SwiftData
import FirebaseAuth

struct FriendActivityBanner: View {
    @State private var trainedToday: [WorkoutFeedItem] = []
    @State private var loaded = false

    private static var fixtureItems: [WorkoutFeedItem] { DevFlags.socialFixtures ? demoItems : [] }
    private static let demoItems: [WorkoutFeedItem] = [
        WorkoutFeedItem(id: "d1", userId: "u1", username: "Marcus", templateName: "Push Day",  exerciseCount: 5, durationSeconds: 3600, caloriesBurned: 418, musclesWorked: ["Chest"], date: Date()),
        WorkoutFeedItem(id: "d2", userId: "u2", username: "Priya",  templateName: "Leg Day",   exerciseCount: 5, durationSeconds: 3300, caloriesBurned: 390, musclesWorked: ["Quads"], date: Date()),
        WorkoutFeedItem(id: "d3", userId: "u3", username: "Jake",   templateName: "Pull Day",  exerciseCount: 5, durationSeconds: 3480, caloriesBurned: 452, musclesWorked: ["Back"],  date: Date()),
    ]

    var body: some View {
        Group {
            if !trainedToday.isEmpty {
                banner
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            guard let uid = Auth.auth().currentUser?.uid else {
                trainedToday = Self.fixtureItems
                return
            }
            let uids = (try? await FirestoreService().fetchFriendUids(for: uid)) ?? []
            if uids.isEmpty {
                trainedToday = Self.fixtureItems
                return
            }
            let posts = (try? await FirestoreService().fetchFeed(friendUids: uids)) ?? []
            let real = posts.filter { Calendar.current.isDateInToday($0.date) }
            trainedToday = real.isEmpty ? Self.fixtureItems : real
        }
    }

    private var banner: some View {
        let names = uniqueNames(from: trainedToday)
        let first = names.first ?? ""
        let others = max(0, trainedToday.count - 1)
        let label = others > 0
            ? "\(first) +\(others) other\(others == 1 ? "" : "s") trained today"
            : "\(first) trained today"

        return Button(action: {}) {
            HStack(spacing: 10) {
                // Overlapping initials
                initialsStack

                Text(label)
                    .font(.archivo(14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.inkFaint, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var initialsStack: some View {
        let names = uniqueNames(from: trainedToday)
        let shown = Array(names.prefix(3))
        let size: CGFloat = 26
        let overlap: CGFloat = 8

        return ZStack(alignment: .leading) {
            ForEach(shown.indices, id: \.self) { i in
                Circle()
                    .fill(Color.surf2)
                    .overlay(Circle().strokeBorder(Color.canvasBg, lineWidth: 1.5))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(shown[i].prefix(1)).uppercased())
                            .font(.spaceMono(9, weight: .bold))
                            .foregroundStyle(Color.inkMuted)
                    )
                    .offset(x: CGFloat(i) * (size - overlap))
            }
        }
        .frame(width: CGFloat(shown.count) * (size - overlap) + overlap, height: size)
    }

    private func uniqueNames(from items: [WorkoutFeedItem]) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item -> String? in
            guard seen.insert(item.userId).inserted else { return nil }
            return item.username
        }
    }
}

// MARK: - Start Workout Bottom Dock
