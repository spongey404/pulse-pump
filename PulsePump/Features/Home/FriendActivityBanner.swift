import SwiftUI
import SwiftData

/// "Marcus +2 others trained today" — from the same feed the Social tab shows (real friends' posts only;
/// nothing is shown when no friend has posted today).
struct FriendActivityBanner: View {
    @State private var viewModel = SocialViewModel.shared

    private var trainedToday: [WorkoutFeedItem] {
        viewModel.feedItems.filter { $0.userId != viewModel.currentUid && Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        Group {
            if !trainedToday.isEmpty {
                banner
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .task { await viewModel.loadFeed() }
    }

    private var banner: some View {
        let names = uniqueNames(from: trainedToday)
        let first = names.first ?? ""
        let others = max(0, names.count - 1)
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
