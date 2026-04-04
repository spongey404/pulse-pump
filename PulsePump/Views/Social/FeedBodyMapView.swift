import SwiftUI

/// Compact, non-interactive body silhouette for feed posts.
/// Converts display name strings back to MuscleGroup and highlights worked muscles.
struct FeedBodyMapView: View {
    let muscleNames: [String]

    private var workedMuscles: Set<MuscleGroup> {
        let matched = muscleNames.compactMap { name in
            MuscleGroup.allCases.first { $0.displayName == name }
        }
        return Set(matched)
    }

    private let frontMuscles: [(MuscleGroup, CGPoint, CGSize)] = [
        (.chest,      CGPoint(x: 0.5, y: 0.22), CGSize(width: 0.28, height: 0.08)),
        (.frontDelts, CGPoint(x: 0.32, y: 0.18), CGSize(width: 0.08, height: 0.06)),
        (.sideDelts,  CGPoint(x: 0.68, y: 0.18), CGSize(width: 0.08, height: 0.06)),
        (.biceps,     CGPoint(x: 0.27, y: 0.3),  CGSize(width: 0.07, height: 0.09)),
        (.forearms,   CGPoint(x: 0.24, y: 0.4),  CGSize(width: 0.06, height: 0.09)),
        (.abs,        CGPoint(x: 0.5, y: 0.35),  CGSize(width: 0.14, height: 0.12)),
        (.obliques,   CGPoint(x: 0.5, y: 0.38),  CGSize(width: 0.22, height: 0.06)),
        (.quads,      CGPoint(x: 0.42, y: 0.55), CGSize(width: 0.1,  height: 0.15)),
        (.adductors,  CGPoint(x: 0.5, y: 0.52),  CGSize(width: 0.06, height: 0.1)),
    ]

    private let backMuscles: [(MuscleGroup, CGPoint, CGSize)] = [
        (.traps,      CGPoint(x: 0.5, y: 0.14),  CGSize(width: 0.16, height: 0.06)),
        (.rearDelts,  CGPoint(x: 0.32, y: 0.18), CGSize(width: 0.08, height: 0.06)),
        (.upperBack,  CGPoint(x: 0.5, y: 0.2),   CGSize(width: 0.22, height: 0.06)),
        (.lats,       CGPoint(x: 0.5, y: 0.28),  CGSize(width: 0.26, height: 0.1)),
        (.triceps,    CGPoint(x: 0.73, y: 0.3),  CGSize(width: 0.07, height: 0.09)),
        (.lowerBack,  CGPoint(x: 0.5, y: 0.38),  CGSize(width: 0.14, height: 0.06)),
        (.glutes,     CGPoint(x: 0.5, y: 0.46),  CGSize(width: 0.2,  height: 0.08)),
        (.hamstrings, CGPoint(x: 0.42, y: 0.58), CGSize(width: 0.1,  height: 0.14)),
        (.calves,     CGPoint(x: 0.42, y: 0.74), CGSize(width: 0.08, height: 0.1)),
    ]

    var body: some View {
        HStack(spacing: 12) {
            silhouette(muscles: frontMuscles)
            silhouette(muscles: backMuscles)
        }
        .frame(height: 110)
    }

    private func silhouette(muscles: [(MuscleGroup, CGPoint, CGSize)]) -> some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(
                        Image(systemName: "figure.stand")
                            .font(.system(size: geo.size.height * 0.65))
                            .foregroundStyle(Color(.systemGray5))
                    )

                ForEach(muscles, id: \.0) { muscle, position, size in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            workedMuscles.contains(muscle)
                                ? Color.pumpPrimary.opacity(0.55)
                                : Color.clear
                        )
                        .frame(
                            width: geo.size.width * size.width,
                            height: geo.size.height * size.height
                        )
                        .position(
                            x: geo.size.width * position.x,
                            y: geo.size.height * position.y
                        )
                }
            }
        }
        .aspectRatio(0.45, contentMode: .fit)
    }
}
