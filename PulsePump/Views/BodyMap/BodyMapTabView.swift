import SwiftUI
import SwiftData

enum HeatmapMode: String, CaseIterable {
    case volume = "Volume"
    case recency = "Recency"
}

enum HeatmapColorScheme: String, CaseIterable, Identifiable {
    case cool
    case warm
    case mono
    case spectrum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cool: "Cool"
        case .warm: "Warm"
        case .mono: "Mono"
        case .spectrum: "Spectrum"
        }
    }

    func color(for intensity: Double, dark: Bool = false) -> Color {
        guard intensity > 0 else { return .clear }
        switch self {
        case .cool:
            return thermalColor(intensity: intensity, dark: dark)
        case .warm:
            if intensity < 0.33 { return .yellow }
            if intensity < 0.66 { return .orange }
            return .red
        case .mono:
            return Color.pumpAccent.opacity(0.3 + intensity * 0.7)
        case .spectrum:
            if intensity < 0.2 { return .blue }
            if intensity < 0.4 { return .cyan }
            if intensity < 0.6 { return .green }
            if intensity < 0.8 { return .yellow }
            return .red
        }
    }

    private func thermalColor(intensity: Double, dark: Bool) -> Color {
        struct Stop { let pos, r, g, b: Double }
        let lightStops = [
            Stop(pos: 0.00, r: 240/255, g: 236/255, b: 226/255),
            Stop(pos: 0.20, r: 236/255, g: 214/255, b: 184/255),
            Stop(pos: 0.45, r: 226/255, g: 170/255, b: 124/255),
            Stop(pos: 0.70, r: 212/255, g: 118/255, b: 88/255),
            Stop(pos: 1.00, r: 192/255, g: 72/255,  b: 60/255),
        ]
        let darkStops = [
            Stop(pos: 0.00, r: 40/255,  g: 38/255,  b: 34/255),
            Stop(pos: 0.20, r: 80/255,  g: 60/255,  b: 50/255),
            Stop(pos: 0.45, r: 148/255, g: 96/255,  b: 64/255),
            Stop(pos: 0.70, r: 220/255, g: 130/255, b: 70/255),
            Stop(pos: 1.00, r: 248/255, g: 100/255, b: 80/255),
        ]
        let stops = dark ? darkStops : lightStops
        var lo = stops[0], hi = stops[stops.count - 1]
        for i in 0..<stops.count - 1 {
            if intensity <= stops[i + 1].pos { lo = stops[i]; hi = stops[i + 1]; break }
        }
        let range = hi.pos - lo.pos
        let t = range > 0 ? (intensity - lo.pos) / range : 0
        return Color(red: lo.r + t * (hi.r - lo.r), green: lo.g + t * (hi.g - lo.g), blue: lo.b + t * (hi.b - lo.b))
    }
}

enum ColdSpotsMode: String, CaseIterable {
    case freq = "FREQ"
    case vol = "VOL"
}

// MARK: - BodyMapTabView

struct BodyMapTabView: View {
    @State private var heatmapMode: HeatmapMode = .volume
    @State private var selectedMuscle: MuscleGroup?
    @State private var colorScheme: HeatmapColorScheme = {
        HeatmapColorScheme(rawValue: UserDefaults.standard.string(forKey: "heatmapColorScheme") ?? "") ?? .cool
    }()
    @State private var selectedDayIndex: Int = -1
    @State private var weekOffset: Int = 0
    private let numWeeks = 4
    @State private var showCalendar = false
    @State private var calendarMonth: Date = Date()
    @State private var selectedCalendarDate: Date? = nil
    @State private var coldSpotsMode: ColdSpotsMode = .freq
    @State private var sheetDetent: PresentationDetent = .height(440)
    @Query private var exerciseLogs: [ExerciseLog]
    @Query private var workouts: [Workout]
    @State private var pulsePlusService = PulsePlusService()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Masthead
                HStack {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.pumpAccent).frame(width: 14, height: 14)
                        Text("PULSE/PUMP")
                            .font(Font.mono(10, weight: .bold)).tracking(2).foregroundStyle(Color.inkPrimary)
                    }
                    Spacer()
                    Text("BODY · LIVE")
                        .font(Font.mono(10)).tracking(1).foregroundStyle(Color.inkMuted)
                    Button {
                        calendarMonth = weekMonday
                        selectedCalendarDate = nil
                        sheetDetent = .height(440)
                        showCalendar = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                            Text("CAL")
                                .font(.spaceMono(9, weight: .bold)).tracking(1)
                        }
                        .foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.surf)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.canvasBg)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                }

                bodyMapContent
            }
            .background(Color.canvasBg.ignoresSafeArea())
        }
        .sheet(isPresented: $showCalendar) {
            calendarSheet
                .presentationDetents([.height(440), .height(580)], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.canvasBg)
        }
        .sheet(item: $selectedMuscle) { muscle in
            MuscleDetailSheet(muscle: muscle, subRegion: nil)
        }
        .task {
            await pulsePlusService.refreshSubscriptionStatus()
        }
    }

    // MARK: - Calendar Panel

    private struct CalDay {
        let date: Date?
        let day: Int?
    }

    private func calendarDays() -> [CalDay] {
        let cal = Calendar.current
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: calendarMonth)),
              let range = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        let weekday = cal.component(.weekday, from: startOfMonth)
        let offset = (weekday + 5) % 7
        var days: [CalDay] = Array(repeating: CalDay(date: nil, day: nil), count: offset)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: startOfMonth) {
                days.append(CalDay(date: date, day: d))
            }
        }
        while days.count < 42 { days.append(CalDay(date: nil, day: nil)) }
        return days
    }

    private func calCell(_ day: CalDay) -> some View {
        let calendar = Calendar.current
        let isSelected = day.date.map { d in selectedCalendarDate.map { calendar.isDate($0, inSameDayAs: d) } ?? false } ?? false
        let isToday    = day.date.map { calendar.isDateInToday($0) } ?? false
        let isFuture   = day.date.map { $0 > Date() } ?? false
        let hasWorkout = !isFuture && (day.date.map { d in workouts.contains { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: d) } } ?? false)

        // Today = solid fill; selected workout = workout bg + strong border; workout = light salmon; regular = cream + hairline
        let bg: Color = isToday ? Color.pumpAccent
                      : hasWorkout ? Color.pumpAccent.opacity(0.12)
                      : day.date != nil ? Color.canvasBg
                      : Color.clear
        let borderColor: Color = isSelected ? Color.accentInk
                               : isToday ? Color.accentInk
                               : hasWorkout ? Color.accentInk.opacity(0.25)
                               : day.date != nil ? Color.dsHairLine
                               : Color.clear
        let borderWidth: CGFloat = isSelected || isToday ? 1.5 : 1
        let numColor: Color = isToday ? .white
                            : isFuture ? Color.inkMuted.opacity(0.25)
                            : hasWorkout ? Color.accentInk
                            : isSelected ? Color.accentInk
                            : Color.inkMuted.opacity(0.55)

        return Button {
            guard let date = day.date, hasWorkout || isToday else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                if isToday && !hasWorkout {
                    selectedCalendarDate = nil
                    sheetDetent = .height(440)
                } else {
                    let newSelection: Date? = isSelected ? nil : date
                    selectedCalendarDate = newSelection
                    sheetDetent = newSelection != nil ? .height(580) : .height(440)
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(bg)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(borderColor, lineWidth: borderWidth))
                VStack(spacing: 3) {
                    if let d = day.day {
                        Text("\(d)")
                            .font(.spaceMono(12, weight: hasWorkout || isToday ? .bold : .regular))
                            .foregroundStyle(numColor)
                        if hasWorkout {
                            Circle()
                                .fill(isToday ? Color.white : Color.pumpAccent)
                                .frame(width: 4, height: 4)
                        } else {
                            Color.clear.frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(day.date == nil || (!hasWorkout && !isToday))
    }

    private var calendarSheet: some View {
        let calendar = Calendar.current
        let canGoNext = calendar.date(byAdding: .month, value: 1, to: calendarMonth)! <= Date()
        let df = DateFormatter(); df.dateFormat = "MMM yyyy"
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        let days = calendarDays()

        return VStack(spacing: 0) {
                // Month navigation
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            calendarMonth = calendar.date(byAdding: .month, value: -1, to: calendarMonth)!
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Text(df.string(from: calendarMonth).uppercased())
                        .font(.archivo(22, weight: .black))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button {
                        if canGoNext {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                calendarMonth = calendar.date(byAdding: .month, value: 1, to: calendarMonth)!
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(canGoNext ? Color.inkMuted : Color.inkMuted.opacity(0.2))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 24)
                .padding(.bottom, 4)

                // Day-of-week headers
                HStack(spacing: 0) {
                    ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                        Text(d)
                            .font(.spaceMono(10))
                            .tracking(0.5)
                            .foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // Calendar grid
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(0..<42, id: \.self) { i in
                        if i < days.count {
                            calCell(days[i])
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .animation(.easeInOut(duration: 0.2), value: calendarMonth)

                // Selected day detail
                if let date = selectedCalendarDate {
                    calendarDayDetail(for: date)
                        .id(date)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedCalendarDate)
                }

                Color.clear.frame(height: 24)
        }
    }

    @ViewBuilder
    private func calendarDayDetail(for date: Date) -> some View {
        let calendar = Calendar.current
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f }()
        let workout = workouts.first { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: date) }
        let logCount = exerciseLogs.filter { log in
            guard let w = log.workout, !w.isDraft else { return false }
            return calendar.isDate(w.date, inSameDayAs: date)
        }.reduce(0) { $0 + $1.sets.count }
        let mins = Int(workout?.duration ?? 0) / 60
        let secs = Int(workout?.duration ?? 0) % 60

        VStack(alignment: .leading, spacing: 8) {
            Text(df.string(from: date).uppercased())
                .font(.spaceMono(9))
                .tracking(1.3)
                .foregroundStyle(Color.inkMuted)

            HStack(alignment: .center) {
                Text(workout?.template?.name.uppercased() ?? "WORKOUT")
                    .font(.archivo(22, weight: .black))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if workout != nil {
                    Button {
                        let today = Date()
                        let selWD = calendar.component(.weekday, from: date)
                        let selMon = calendar.date(byAdding: .day, value: -(selWD == 1 ? 6 : selWD - 2), to: calendar.startOfDay(for: date))!
                        let todWD = calendar.component(.weekday, from: today)
                        let thisMon = calendar.date(byAdding: .day, value: -(todWD == 1 ? 6 : todWD - 2), to: calendar.startOfDay(for: today))!
                        let weekDiff = calendar.dateComponents([.weekOfYear], from: selMon, to: thisMon).weekOfYear ?? 0
                        weekOffset = max(-(numWeeks - 1), -weekDiff)
                        selectedDayIndex = selWD == 1 ? 6 : selWD - 2
                        showCalendar = false
                    } label: {
                        Text("VIEW")
                            .font(.spaceMono(9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 30)
                            .background(Color.pumpAccent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if workout != nil {
                HStack(spacing: 6) {
                    Text("\(logCount) SETS")
                    Text("·").foregroundStyle(Color.inkFaint)
                    Text(String(format: "%d:%02d", mins, secs))
                }
                .font(.spaceMono(10))
                .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(Font.spaceMono(8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.inkMuted)
        }
    }

    // MARK: - Body Map Content

    private var bodyMapContent: some View {
        VStack(spacing: 0) {
            if !tickerItems.isEmpty {
                TickerStripView(items: tickerItems)
            }

            ScrollView {
                VStack(spacing: 0) {
                    // Hero stat row
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDayLabel.uppercased())
                                .font(Font.mono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(selectedTotalSets)")
                                    .font(.display(64))
                                    .foregroundStyle(Color.inkPrimary)
                                    .lineLimit(1)
                                Text("/ \(selectedDayIndex == -1 ? weeklyTarget : dailyTarget)")
                                    .font(Font.mono(11)).foregroundStyle(Color.inkMuted)
                            }
                            Text("SETS · \(Int(Double(selectedTotalSets) / Double(max(selectedDayIndex == -1 ? weeklyTarget : dailyTarget, 1)) * 100))% TGT")
                                .font(Font.mono(10)).foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("VS LAST")
                                .font(Font.mono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            Text(vsLastText)
                                .font(.display(32)).foregroundStyle(vsLastColor)
                            Text("\(musclesWorkedCount)/\(MuscleGroup.allCases.count) GROUPS")
                                .font(Font.mono(10)).foregroundStyle(Color.inkMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Day scrubber
                    dayScrubber

                    // Body + TOP/GAPS
                    HStack(spacing: 0) {
                        // TOP column
                        VStack(alignment: .leading, spacing: 12) {
                            Text("▲ TOP")
                                .font(Font.mono(9, weight: .medium)).tracking(2.0).foregroundStyle(Color.accentInk)
                            ForEach(topMuscles, id: \.key) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.key.uppercased().prefix(5))
                                        .font(Font.mono(10, weight: .bold)).foregroundStyle(Color.inkPrimary)
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text("\(item.sets)")
                                            .font(.display(22)).foregroundStyle(Color.inkPrimary)
                                        Text("/\(item.target)")
                                            .font(Font.mono(9)).foregroundStyle(Color.inkMuted)
                                    }
                                    Text("\(item.ratio >= 1 ? "▲" : "●") \(Int(item.ratio * 100))%")
                                        .font(Font.mono(9)).foregroundStyle(item.ratio >= 1 ? Color.signalUp : Color.inkMuted)
                                }
                            }
                            Spacer()
                        }
                        .frame(width: 72)
                        .padding(.leading, 14)
                        .padding(.top, 10)

                        // Body model (center)
                        BodyModelView(
                            heatmapMode: heatmapMode,
                            exerciseLogs: filteredLogs,
                            colorScheme: colorScheme,
                            normalization: selectedDayIndex >= 0 ? .relativeToDay : .relativeToTarget,
                            onMuscleTap: { muscle in selectedMuscle = muscle }
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)

                        // GAPS column
                        VStack(alignment: .trailing, spacing: 12) {
                            Text("▼ GAPS")
                                .font(Font.mono(9, weight: .medium)).tracking(2.0).foregroundStyle(Color.accentInk)
                            ForEach(gapMuscles, id: \.key) { item in
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(item.key.uppercased().prefix(5))
                                        .font(Font.mono(10, weight: .bold)).foregroundStyle(Color.inkPrimary)
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text("\(item.sets)")
                                            .font(.display(22)).foregroundStyle(Color.inkPrimary)
                                        Text("/\(item.target)")
                                            .font(Font.mono(9)).foregroundStyle(Color.inkMuted)
                                    }
                                    Text("\(item.ratio < 0.5 ? "▼" : "●") \(Int(item.ratio * 100))%")
                                        .font(Font.mono(9)).foregroundStyle(item.ratio < 0.5 ? Color.signalDown : Color.inkMuted)
                                }
                            }
                            Spacer()
                        }
                        .frame(width: 72)
                        .padding(.trailing, 14)
                        .padding(.top, 10)
                    }
                    .frame(height: 300)

                    // Cold Spots
                    coldSpotsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    Color.clear.frame(height: 16)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Cold Spots Section

    private var coldSpotsSection: some View {
        let spots = coldSpotsData
        let staleOrUnderCount = spots.filter { $0.isFlagged }.count

        return VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text(coldSpotsMode == .freq
                     ? "COLD SPOTS · \(staleOrUnderCount) STALE"
                     : "UNDER TARGET · \(staleOrUnderCount) LOW")
                    .font(.spaceMono(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                Spacer()
                // FREQ / VOL toggle — each button has its own border box
                HStack(spacing: 6) {
                    ForEach(ColdSpotsMode.allCases, id: \.self) { m in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { coldSpotsMode = m }
                        } label: {
                            Text(m.rawValue)
                                .font(.spaceMono(10, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(coldSpotsMode == m ? Color.inkPrimary : Color.inkMuted)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(Color.canvasBg)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            coldSpotsMode == m ? Color.inkPrimary : Color.dsHairLine,
                                            lineWidth: coldSpotsMode == m ? 1.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 3 equal-width cards
            HStack(spacing: 8) {
                ForEach(spots) { spot in
                    coldSpotCard(spot)
                }
            }
        }
    }

    private struct ColdSpotItem: Identifiable {
        let id = UUID()
        let muscleName: String
        let value: Int
        let target: Int
        let isFlagged: Bool
        var ratio: Double { Double(value) / Double(max(target, 1)) }
    }

    private var coldSpotsData: [ColdSpotItem] {
        let targets: [MuscleGroup: Int] = [
            .chest: 16, .lats: 16, .quads: 20, .hamstrings: 12,
            .glutes: 12, .frontDelts: 8, .sideDelts: 10, .rearDelts: 8,
            .biceps: 10, .triceps: 10, .traps: 8, .upperBack: 12
        ]
        let cadence: [MuscleGroup: Int] = [
            .chest: 4, .lats: 4, .quads: 4, .hamstrings: 5,
            .glutes: 5, .frontDelts: 3, .sideDelts: 3, .rearDelts: 3,
            .biceps: 4, .triceps: 4, .traps: 5, .upperBack: 4
        ]
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        if coldSpotsMode == .freq {
            // Sort by days since last trained
            return targets.keys.map { muscle in
                var latest: Date? = nil
                for log in exerciseLogs {
                    guard let ex = log.exercise, let w = log.workout, !w.isDraft else { continue }
                    if ex.primaryMuscleGroups.contains(muscle) || ex.secondaryMuscleGroups.contains(muscle) {
                        if latest == nil || w.date > latest! { latest = w.date }
                    }
                }
                let days = latest.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: Date())).day ?? 0 } ?? 99
                let cad = cadence[muscle] ?? 4
                return ColdSpotItem(
                    muscleName: muscle.displayName,
                    value: days,
                    target: cad,
                    isFlagged: days >= Int(Double(cad) * 1.5)
                )
            }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0 }
        } else {
            // Sort by completion ratio (lowest first)
            var setsByMuscle: [MuscleGroup: Int] = [:]
            for log in exerciseLogs {
                guard let ex = log.exercise, let w = log.workout, !w.isDraft, w.date >= weekAgo else { continue }
                for m in ex.primaryMuscleGroups { setsByMuscle[m, default: 0] += log.sets.count }
                for m in ex.secondaryMuscleGroups { setsByMuscle[m, default: 0] += log.sets.count / 2 }
            }
            return targets.keys.map { muscle in
                let sets = setsByMuscle[muscle] ?? 0
                let tgt = targets[muscle] ?? 10
                return ColdSpotItem(
                    muscleName: muscle.displayName,
                    value: sets,
                    target: tgt,
                    isFlagged: Double(sets) / Double(tgt) < 0.5
                )
            }
            .sorted { $0.ratio < $1.ratio }
            .prefix(3)
            .map { $0 }
        }
    }

    private func coldSpotCard(_ spot: ColdSpotItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(spot.muscleName.uppercased())
                .font(.spaceMono(9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(coldSpotsMode == .freq ? "\(spot.value)d" : "\(spot.value)")
                    .font(.display(24))
                    .foregroundStyle(Color.inkPrimary)
                Text(coldSpotsMode == .freq ? "/ \(spot.target)d" : "/ \(spot.target)")
                    .font(.mono(10))
                    .foregroundStyle(Color.inkMuted)
            }

            // Underline progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.inkPrimary.opacity(0.08))
                        .frame(height: 2)
                    Rectangle()
                        .fill(spot.isFlagged ? Color.signalDown : Color.inkPrimary.opacity(0.7))
                        .frame(width: geo.size.width * min(spot.ratio, 1.0), height: 2)
                }
            }
            .frame(height: 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.canvasBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.dsHairLine, lineWidth: 0.5))
    }

    // MARK: - Day Scrubber

    private var weekMonday: Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let thisMon = calendar.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: today)!
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisMon)!
    }

    // tabIndex 0 = oldest week, numWeeks-1 = current week
    private var tabIndexBinding: Binding<Int> {
        Binding(
            get: { max(0, min(numWeeks - 1, weekOffset + (numWeeks - 1))) },
            set: { newTab in
                let newOffset = newTab - (numWeeks - 1)
                if newOffset != weekOffset {
                    weekOffset = newOffset
                    selectedDayIndex = -1
                }
            }
        )
    }

    private var dayScrubber: some View {
        VStack(spacing: 6) {
            TabView(selection: tabIndexBinding) {
                ForEach(0..<numWeeks, id: \.self) { tab in
                    weekStrip(weekOffset: tab - (numWeeks - 1))
                        .padding(.horizontal, 16)
                        .tag(tab)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 70)

            // Page dots
            HStack(spacing: 5) {
                ForEach(0..<numWeeks, id: \.self) { i in
                    let active = tabIndexBinding.wrappedValue == i
                    Circle()
                        .fill(active ? Color.inkPrimary : Color.inkPrimary.opacity(0.2))
                        .frame(width: active ? 6 : 4, height: active ? 6 : 4)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: tabIndexBinding.wrappedValue)
                }
            }
            .padding(.bottom, 2)
        }
        .padding(.vertical, 4)
    }

    private func weekStrip(weekOffset offset: Int) -> some View {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let thisMon = calendar.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: today)!
        let monday = calendar.date(byAdding: .weekOfYear, value: offset, to: thisMon)!
        let weekNumber = calendar.component(.weekOfYear, from: monday)
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        return HStack(spacing: 6) {
            // WEEK pill
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDayIndex = -1 }
            } label: {
                let active = selectedDayIndex == -1 && weekOffset == offset
                VStack(spacing: 2) {
                    Text("WEEK")
                        .font(.mono(8)).tracking(1)
                    Text("\(weekNumber)")
                        .font(.mono(14, weight: .bold))
                    Color.clear.frame(width: 14, height: 2)
                }
                .foregroundStyle(active ? Color.canvasBg : Color.inkPrimary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(active ? Color.inkPrimary : Color.inkPrimary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                    active ? Color.clear : Color.dsHairLine, lineWidth: 1))
            }
            .buttonStyle(PressScaleButtonStyle())

            // Day pills
            ForEach(0..<7, id: \.self) { i in
                let date = calendar.date(byAdding: .day, value: i, to: monday)!
                let dayNum = calendar.component(.day, from: date)
                let hasWorkout = workouts.contains { w in !w.isDraft && calendar.isDate(w.date, inSameDayAs: date) }
                let active = selectedDayIndex == i && weekOffset == offset

                Button {
                    weekOffset = offset
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDayIndex = i }
                } label: {
                    VStack(spacing: 2) {
                        Text(dayLabels[i])
                            .font(.mono(9)).tracking(1)
                        Text("\(dayNum)")
                            .font(.mono(14, weight: .bold))
                        if hasWorkout && !active {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.pumpAccent.opacity(0.6))
                                .frame(width: 14, height: 2)
                        } else {
                            Color.clear.frame(width: 14, height: 2)
                        }
                    }
                    .foregroundStyle(active ? Color.canvasBg : (hasWorkout ? Color.inkPrimary : Color.inkMuted))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(active ? Color.inkPrimary : Color.inkPrimary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                        active ? Color.clear : Color.dsHairLine, lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    // MARK: - Data Computations

    private var filteredLogs: [ExerciseLog] {
        let calendar = Calendar.current
        let monday = weekMonday
        if selectedDayIndex >= 0 {
            let targetDate = calendar.date(byAdding: .day, value: selectedDayIndex, to: monday)!
            return exerciseLogs.filter { log in
                guard let workout = log.workout, !workout.isDraft else { return false }
                return calendar.isDate(workout.date, inSameDayAs: targetDate)
            }
        } else {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: monday) else { return exerciseLogs }
            return exerciseLogs.filter { log in
                guard let workout = log.workout, !workout.isDraft else { return false }
                return workout.date >= monday && workout.date < weekEnd
            }
        }
    }

    private var selectedTotalSets: Int {
        filteredLogs.reduce(0) { $0 + $1.sets.count }
    }

    private let weeklyTarget = 132
    private let dailyTarget = 22

    private var selectedDayLabel: String {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        if selectedDayIndex >= 0 {
            let dayNames = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            let date = calendar.date(byAdding: .day, value: selectedDayIndex, to: weekMonday)!
            let workout = workouts.first { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: date) }
            let workoutName = workout?.template?.name.uppercased() ?? (workout != nil ? "WORKOUT" : "REST")
            return "\(dayNames[selectedDayIndex]) · \(df.string(from: date).uppercased()) · \(workoutName)"
        } else {
            let weekNum = calendar.component(.weekOfYear, from: weekMonday)
            let sunday = calendar.date(byAdding: .day, value: 6, to: weekMonday)!
            return "WEEK \(weekNum) · \(df.string(from: weekMonday).uppercased())–\(df.string(from: sunday).uppercased())"
        }
    }

    private var vsLastText: String {
        let thisWeekSets = thisWeekSets()
        let lastWeekSets = lastWeekSets()
        guard lastWeekSets > 0 else { return "—" }
        let pct = Double(thisWeekSets - lastWeekSets) / Double(lastWeekSets) * 100
        return pct >= 0 ? "+\(Int(pct))%" : "\(Int(pct))%"
    }

    private var vsLastColor: Color {
        let text = vsLastText
        if text == "—" { return Color.inkMuted }
        return text.hasPrefix("+") ? Color.signalUp : Color.signalDown
    }

    private var musclesWorkedCount: Int {
        var muscles = Set<MuscleGroup>()
        for log in filteredLogs {
            guard let exercise = log.exercise else { continue }
            muscles.formUnion(exercise.primaryMuscleGroups)
        }
        return muscles.count
    }

    private struct MuscleItem: Identifiable {
        let id = UUID()
        let key: String
        let sets: Int
        let target: Int
        var ratio: Double { Double(sets) / Double(max(target, 1)) }
    }

    private var muscleSetsData: [MuscleItem] {
        let targets: [MuscleGroup: Int] = [
            .chest: 16, .lats: 16, .quads: 20, .hamstrings: 12,
            .glutes: 12, .frontDelts: 8, .sideDelts: 10, .rearDelts: 8,
            .biceps: 10, .triceps: 10, .traps: 8, .upperBack: 12
        ]
        var setsByMuscle: [MuscleGroup: Int] = [:]
        for log in filteredLogs {
            guard let exercise = log.exercise else { continue }
            for muscle in exercise.primaryMuscleGroups {
                setsByMuscle[muscle, default: 0] += log.sets.count
            }
        }
        return targets.map { muscle, target in
            MuscleItem(key: muscle.displayName, sets: setsByMuscle[muscle] ?? 0, target: target)
        }.sorted { $0.ratio > $1.ratio }
    }

    private var topMuscles: [MuscleItem] { Array(muscleSetsData.prefix(3)) }
    private var gapMuscles: [MuscleItem] { Array(muscleSetsData.suffix(3).reversed()) }

    private var tickerItems: [TickerItem] {
        guard selectedTotalSets > 0 else { return [] }
        let items: [TickerItem] = [
            TickerItem(label: "SETS", value: "\(selectedTotalSets)", direction: nil),
            TickerItem(label: "GROUPS", value: "\(musclesWorkedCount)", direction: nil),
            TickerItem(label: "VS LAST", value: vsLastText, direction: vsLastText.hasPrefix("+") ? .up : (vsLastText == "—" ? nil : .down)),
        ] + topMuscles.map { TickerItem(label: $0.key.uppercased(), value: "\($0.sets)s", direction: $0.ratio >= 1 ? .up : nil) }
        return items + items
    }

    private func thisWeekSets() -> Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return exerciseLogs.reduce(0) { count, log in
            guard let workout = log.workout, !workout.isDraft, workout.date >= weekAgo else { return count }
            return count + log.sets.count
        }
    }

    private func lastWeekSets() -> Int {
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return exerciseLogs.reduce(0) { count, log in
            guard let workout = log.workout, !workout.isDraft,
                  workout.date >= twoWeeksAgo, workout.date < oneWeekAgo else { return count }
            return count + log.sets.count
        }
    }
}

// MARK: - Muscle Balance Analysis (Pulse+)

struct MuscleBalanceView: View {
    let exerciseLogs: [ExerciseLog]

    private var pushVolume: Int { weeklyVolume(for: [.chest, .frontDelts, .sideDelts, .triceps]) }
    private var pullVolume: Int { weeklyVolume(for: [.lats, .upperBack, .rearDelts, .biceps, .traps]) }
    private var quadVolume: Int { weeklyVolume(for: [.quads]) }
    private var hamVolume: Int  { weeklyVolume(for: [.hamstrings, .glutes]) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MUSCLE BALANCE")
                .font(Font.mono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            BalanceBar(label: "PUSH / PULL", left: pushVolume, right: pullVolume, leftLabel: "Push", rightLabel: "Pull")
            BalanceBar(label: "QUADS / POSTERIOR", left: quadVolume, right: hamVolume, leftLabel: "Quads", rightLabel: "Hams/Glutes")
        }
        .padding(14)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.dsHairLine, lineWidth: 0.5))
    }

    private func weeklyVolume(for muscles: [MuscleGroup]) -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var total = 0
        for log in exerciseLogs {
            guard let exercise = log.exercise,
                  let workout = log.workout,
                  !workout.isDraft,
                  workout.date >= weekAgo else { continue }
            if !Set(exercise.primaryMuscleGroups).intersection(muscles).isEmpty {
                total += log.sets.count
            }
        }
        return total
    }
}

struct BalanceBar: View {
    let label: String
    let left: Int
    let right: Int
    let leftLabel: String
    let rightLabel: String

    private var total: Int { max(left + right, 1) }
    private var leftRatio: Double { Double(left) / Double(total) }
    private var isImbalanced: Bool {
        guard total > 0 else { return false }
        let ratio = left > right ? Double(left) / max(Double(right), 1) : Double(right) / max(Double(left), 1)
        return ratio > 1.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(Font.mono(9)).tracking(0.5).foregroundStyle(Color.inkMuted)
                Spacer()
                if isImbalanced {
                    Image(systemName: "exclamationmark.triangle").font(.mono(9)).foregroundStyle(Color.signalDown)
                }
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.pumpAccent)
                        .frame(width: max(geo.size.width * leftRatio, 4))
                    RoundedRectangle(cornerRadius: 3).fill(Color.signalUp)
                }
            }
            .frame(height: 8)
            HStack {
                Text("\(leftLabel): \(left) sets").font(Font.mono(9)).foregroundStyle(Color.inkMuted)
                Spacer()
                Text("\(rightLabel): \(right) sets").font(Font.mono(9)).foregroundStyle(Color.inkMuted)
            }
        }
    }
}
