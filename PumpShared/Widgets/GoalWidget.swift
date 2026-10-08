import SwiftUI

// MARK: - 11 Weekly session goal  (Pump Widgets.dc.html · w9)

struct GoalWidget: View {
    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    var body: some View {
        let goal = max(snap.sessionGoal, 1)
        VStack(alignment: .leading, spacing: 0) {
            Text("GOAL · WK \(snap.weekNumber)").pwCap()
            Text("\(snap.sessionsThisWeek)/\(snap.sessionGoal)").pwMono(48, bold: true)
                .frame(height: 48 * 1.1, alignment: .leading).padding(.top, 6)
            Text("SESSIONS").pwCap(8, tracking: 1.2)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(0..<goal, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < snap.sessionsThisWeek ? PumpTheme.ink : PumpTheme.faint)
                        .frame(height: 20)
                }
            }
            Text(snap.fixed.goalLeftLine).pwCap(8, tracking: 1.2).padding(.top, 6)
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }
}

extension GoalWidget {
    static let blurb = "Weekly session goal from the profile, one square per session."
    static var gallery: [PWGalleryItem] {
        [PWGalleryItem("11 · SMALL", .small) { AnyView(GoalWidget(family: .small, snap: $0)) }]
    }
}
