import SwiftUI

// MARK: - 02 Streak  (pump_widgets.html · w2)
// 2A small: big count + 7-day squares · 2B small: count + last session + week bars ·
// 2 medium: squares + last workout · 2 large: START, week bars, recent list.

struct StreakWidget: View {
    static let blurb = "The existing widget restyled. Same data from WidgetDataService. Gap-based, so rest days show as empty squares without breaking the count. Large keeps the recent sessions list and gains START."

    let family: PWFamily
    var variant: PWVariant = .a
    let snap: PumpWidgetSnapshot

    private var f: PWFixedData { snap.fixed }

    var body: some View {
        Group {
            switch (family, variant) {
            case (.small, .a): smallA
            case (.small, .b): smallB
            case (.medium, _): medium
            case (.large, _): large
            }
        }
        .padding(family.padding)
        .frame(width: family.size.width, height: family.size.height, alignment: .topLeading)
    }

    private func count(_ size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(snap.streak)").pwMono(size, bold: true)
            Text("DAYS").pwCap()
        }
    }

    private func squares(height: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(f.streakLogged.enumerated()), id: \.offset) { i, on in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(on ? PumpTheme.ink : PumpTheme.faint)
                        .frame(height: height)
                    Text(f.streakLetters.indices.contains(i) ? f.streakLetters[i] : "").pwCap(7, tracking: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // 2A · small
    private var smallA: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STREAK").pwCap()
            count(56).padding(.top, 4)
            Spacer(minLength: 0)
            squares(height: 14)
        }
    }

    // 2B · small
    private var smallB: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(snap.streak)").pwMono(36, bold: true)
                Spacer()
                Text("DAY STREAK").pwCap(8, tracking: 1.2)
            }
            Text("LAST · \(f.lastWorkoutName.uppercased()) · \(f.lastWorkoutWeekday)").pwCap(8, tracking: 1.2)
                .lineLimit(1).minimumScaleFactor(0.7).padding(.top, 6)
            Spacer(minLength: 0)
            PWWeekBars(data: f.weekSetsPerDay, done: f.weekDone, today: f.todayIndex, height: 44)
        }
    }

    // 2 · medium
    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("STREAK").pwCap()
                count(48).padding(.top, 4)
                Spacer(minLength: 0)
                squares(height: 12)
            }
            .frame(width: 150)
            PWHair(vertical: true)
            VStack(alignment: .leading, spacing: 0) {
                Text("LAST WORKOUT").pwCap()
                Text(f.lastWorkoutName).pwBody(18, weight: .bold).lineLimit(1).padding(.top, 8)
                Text("\(f.lastWorkoutDaysAgo) DAYS AGO").pwCap(8, tracking: 1.2).padding(.top, 4)
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    PWHair()
                    HStack(spacing: 0) {
                        stat("EX", "\(f.lastWorkoutExercises)")
                        stat("MIN", "\(f.lastWorkoutMinutes)")
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).pwCap(8, tracking: 1.2)
            Text(v).pwMono(16, bold: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 2 · large
    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("STREAK").pwCap()
                    count(48)
                }
                Spacer()
                startLink(Text("START ›").font(.archivo(13, weight: .black)).tracking(0.5).foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(PumpTheme.accent, in: RoundedRectangle(cornerRadius: 12)))
            }
            PWWeekBars(data: f.weekSetsPerDay, done: f.weekDone, today: f.todayIndex, height: 48).padding(.top, 12)
            HStack {
                Text("RECENT").pwCap()
                Spacer()
                Text("WK \(snap.weekNumber)").pwCap(8, tracking: 1.2)
            }
            .padding(.top, 16).padding(.bottom, 6)
            .overlay(alignment: .bottom) { PWHair() }
            ForEach(Array(f.recentSessions.prefix(3).enumerated()), id: \.offset) { _, r in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.name).pwBody(14)
                        Text(r.when).pwCap(8, tracking: 1.2)
                    }
                    Spacer()
                    Text(r.meta).pwMono(10, color: PumpTheme.secondary, tracking: 1)
                }
                .frame(height: 52)
                .overlay(alignment: .bottom) { PWHair() }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func startLink<V: View>(_ label: V) -> some View {
        if let url = PumpWidgetSnapshot.startURL(template: snap.nextName) { Link(destination: url) { label } } else { label }
    }
}

extension StreakWidget {
    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("2A · SMALL", .small) { AnyView(StreakWidget(family: .small, variant: .a, snap: $0)) },
            PWGalleryItem("2B · SMALL", .small) { AnyView(StreakWidget(family: .small, variant: .b, snap: $0)) },
            PWGalleryItem("2 · MEDIUM", .medium) { AnyView(StreakWidget(family: .medium, variant: .a, snap: $0)) },
            PWGalleryItem("2 · LARGE", .large) { AnyView(StreakWidget(family: .large, variant: .a, snap: $0)) },
        ]
    }
}
