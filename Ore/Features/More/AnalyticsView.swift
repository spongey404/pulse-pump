import SwiftUI
import SwiftData

/// More › Analytics: estimated 1RM per exercise over 30 days and weekly volume. Real data only (`AnalyticsStats`).
struct AnalyticsView: View {
    let onBack: () -> Void
    @Environment(\.weightUnit) private var unit
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    var body: some View {
        let stats = AnalyticsStats(workouts: workouts)
        let rows = stats.e1RMRows()
        VStack(spacing: 0) {
            MoreScreenHeader(title: "ANALYTICS", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MoreSectionLabel(title: "ESTIMATED 1RM · 30 DAYS")
                    if rows.isEmpty {
                        Text("Log a few sets and your estimated 1RMs show up here.")
                            .font(.archivo(13)).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    }
                    ForEach(rows, id: \.name) { row in
                        HStack(spacing: 16) {
                            Text(row.name).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 6) {
                                Text(String(format: "%.1f", unit.display(row.e1rmKg)) + " " + unit.label.uppercased())
                                    .font(.spaceMono(10)).tracking(0.8).foregroundStyle(Color.inkMuted)
                                if let change = row.change { Text(Self.changeText(change)).font(.spaceMono(10, weight: .bold)).tracking(0.8).foregroundStyle(change >= 0 ? Color.signalUp : Color.signalDown) }
                            }
                        }
                        .padding(.vertical, 14).padding(.horizontal, 16).frame(minHeight: 44)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        .accessibilityElement(children: .combine)
                    }

                    MoreSectionLabel(title: "VOLUME")
                    volumeRow("This week", stats.volumeKg(weeksBack: 0))
                    volumeRow("Last week", stats.volumeKg(weeksBack: 1))
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }

    private func volumeRow(_ label: String, _ kg: Double) -> some View {
        HStack(spacing: 16) {
            Text(label).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(maxWidth: .infinity, alignment: .leading)
            Text(Self.volumeText(kg, unit: unit)).font(.spaceMono(10)).tracking(0.8).foregroundStyle(Color.inkMuted)
        }
        .padding(.vertical, 14).padding(.horizontal, 16).frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    /// "▲ 4.2%" / "▼ 1.0%".
    static func changeText(_ change: Double) -> String {
        String(format: "%@ %.1f%%", change >= 0 ? "▲" : "▼", abs(change * 100))
    }

    /// Thousands of the display unit: "12.4 T" for kg, "27.3 K LB" for lb.
    static func volumeText(_ kg: Double, unit: UnitPreference) -> String {
        guard kg > 0 else { return "—" }
        let v = unit.display(kg) / 1000
        return unit == .kg ? String(format: "%.1f T", v) : String(format: "%.1f K LB", v)
    }
}
