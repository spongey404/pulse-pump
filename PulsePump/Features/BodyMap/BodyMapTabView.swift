import SwiftUI
import SwiftData

enum HeatmapMode: String, CaseIterable {
    case volume = "Volume"
    case recency = "Recency"
}

enum ColdSpotsMode: String, CaseIterable {
    case freq = "FREQ"
    case vol = "VOL"
}

// MARK: - BodyMapTabView  (design: Body Tab.dc.html · v3, front and back 2D maps)

struct BodyMapTabView: View {
    @State private var heatmapMode: HeatmapMode = .volume
    @State private var selectedMuscle: MuscleGroup?
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

    // MARK: Targets (sets per week) and training cadence (days) for the 17 tracked groups

    private static let tracked: [MuscleGroup] = [
        .chest, .lats, .quads, .hamstrings, .glutes, .frontDelts, .sideDelts, .rearDelts,
        .biceps, .triceps, .traps, .upperBack, .forearms, .lowerBack, .calves, .abs, .obliques,
    ]
    private static let targets: [MuscleGroup: Int] = [
        .chest: 16, .lats: 16, .quads: 20, .hamstrings: 12, .glutes: 12,
        .frontDelts: 8, .sideDelts: 10, .rearDelts: 8, .biceps: 10, .triceps: 10,
        .traps: 8, .upperBack: 12, .forearms: 6, .lowerBack: 6, .calves: 8, .abs: 8, .obliques: 6,
    ]
    private static let cadence: [MuscleGroup: Int] = [
        .chest: 4, .lats: 4, .quads: 4, .hamstrings: 5, .glutes: 5,
        .frontDelts: 3, .sideDelts: 3, .rearDelts: 3, .biceps: 4, .triceps: 4,
        .traps: 5, .upperBack: 4, .forearms: 5, .lowerBack: 5, .calves: 5, .abs: 4, .obliques: 5,
    ]
    private static let abbr: [MuscleGroup: String] = [
        .chest: "CHEST", .lats: "LATS", .quads: "QUADS", .hamstrings: "HAMS", .glutes: "GLUTE",
        .frontDelts: "F.DELT", .sideDelts: "S.DELT", .rearDelts: "R.DELT", .biceps: "BICEPS",
        .triceps: "TRICEPS", .traps: "TRAPS", .upperBack: "U.BACK", .forearms: "FOREARM",
        .lowerBack: "L.BACK", .calves: "CALVES", .abs: "ABS", .obliques: "OBLIQ",
    ]
    private let weeklyTarget = BodyMapTabView.targets.values.reduce(0, +)
    private let dailyTarget = 26

    /// Generic groups on older exercises fold into the 17 tracked ones.
    private func tracked(_ m: MuscleGroup) -> MuscleGroup? {
        switch m {
        case .back: .upperBack
        case .shoulders: .sideDelts
        default: Self.targets[m] != nil ? m : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            masthead
            bodyMapContent
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .sheet(isPresented: $showCalendar) {
            calendarSheet
                .presentationDetents([.height(440), .height(560)], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.canvasBg)
                .presentationCornerRadius(8)
        }
        .sheet(item: $selectedMuscle) { muscle in
            MuscleDetailSheet(muscle: muscle, subRegion: nil)
        }
        .task {
            await pulsePlusService.refreshSubscriptionStatus()
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(Color.pumpAccent).frame(width: 16, height: 16)
                Text("PULSE/PUMP")
                    .font(.spaceMono(10, weight: .bold)).tracking(2).foregroundStyle(Color.inkPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                calendarMonth = weekMonday
                selectedCalendarDate = nil
                sheetDetent = .height(440)
                showCalendar = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 11, weight: .regular))
                    Text("CAL").font(.spaceMono(9, weight: .bold)).tracking(1)
                }
                .foregroundStyle(Color.inkPrimary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }
    }

    // MARK: - Content

    private var bodyMapContent: some View {
        VStack(spacing: 0) {
            let items = tickerItems
            if !items.isEmpty { TickerStripView(items: items) }

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    weekRow
                    dayScrubber

                    // SHOW + map
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Text("SHOW").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            chip("VOLUME", active: heatmapMode == .volume) { heatmapMode = .volume }
                            chip("LAST 48H", active: heatmapMode == .recency) { heatmapMode = .recency }
                        }
                        .padding(.bottom, 10)

                        BodyMap2DView(levels: heatLevels) { selectedMuscle = $0 }
                            .frame(height: 290)

                        HStack(spacing: 6) {
                            Text(heatmapMode == .recency ? "48H+ AGO" : "0%")
                            LinearGradient(colors: [Color.inkPrimary.opacity(0.035), Color.pumpAccent],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: 120, height: 4)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Text(heatmapMode == .recency ? "JUST TRAINED" : "100% OF TARGET")
                        }
                        .font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    topGaps
                    coldSpotsSection
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { action() } } label: {
            Text(label)
                .font(.spaceMono(9, weight: .bold)).tracking(1)
                .foregroundStyle(active ? Color.canvasBg : Color.inkMuted)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(active ? Color.inkPrimary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(active ? Color.clear : Color.dsHairLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDayLabel)
                    .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(selectedTotalSets)")
                        .font(.spaceMono(56, weight: .bold)).tracking(-2).foregroundStyle(Color.inkPrimary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("/ \(selectedDayIndex == -1 ? weeklyTarget : dailyTarget)")
                        .font(.spaceMono(11)).foregroundStyle(Color.inkMuted)
                }
                Text("SETS · \(musclesWorkedCount)/17 GROUPS")
                    .font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 0)
            let vs = vsInfo
            VStack(alignment: .trailing, spacing: 4) {
                Text(vs.label).font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                Text(vs.value).font(.spaceMono(20, weight: .bold)).foregroundStyle(vs.color)
                Text(vs.sub).font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            .padding(.bottom, 1)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
    }

    private struct VSInfo { let label: String; let value: String; let color: Color; let sub: String }

    private func pctText(_ p: Int) -> String { p > 0 ? "▲ +\(p)%" : p < 0 ? "▼ \(p)%" : "● 0%" }
    private func pctColor(_ p: Int) -> Color { p > 0 ? .signalUp : p < 0 ? .signalDown : .inkMuted }

    private var vsInfo: VSInfo {
        let cal = Calendar.current
        if selectedDayIndex >= 0 {
            let date = cal.date(byAdding: .day, value: selectedDayIndex, to: weekMonday)!
            guard let w = workouts.first(where: { !$0.isDraft && cal.isDate($0.date, inSameDayAs: date) }) else {
                return VSInfo(label: "VS LAST", value: "—", color: .inkMuted, sub: "REST DAY")
            }
            let name = w.template?.name
            let prev = workouts.filter { !$0.isDraft && $0.date < w.date && $0.template?.name == name && name != nil }
                .max(by: { $0.date < $1.date })
            let cur = setCount(w)
            if let prev, setCount(prev) > 0 {
                let p = Int((Double(cur - setCount(prev)) / Double(setCount(prev)) * 100).rounded())
                let f = DateFormatter(); f.dateFormat = "MMM d"
                return VSInfo(label: "VS LAST " + (name?.uppercased().split(separator: " ").first.map(String.init) ?? ""),
                              value: pctText(p), color: pctColor(p),
                              sub: "\(f.string(from: prev.date).uppercased()) · \(setCount(prev)) SETS")
            }
            return VSInfo(label: "VS LAST", value: "—", color: .inkMuted, sub: "FIRST SESSION")
        }
        let prevTotal = setsInWeek(offset: weekOffset - 1)
        if weekOffset == 0 {
            let elapsed = (cal.dateComponents([.day], from: weekMonday, to: cal.startOfDay(for: Date())).day ?? 0) + 1
            let expected = max(1, Int((Double(weeklyTarget) * Double(elapsed) / 7).rounded()))
            let p = Int((Double(selectedTotalSets - expected) / Double(expected) * 100).rounded())
            let dayNames = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            return VSInfo(label: "VS PACE", value: pctText(p), color: pctColor(p),
                          sub: "\(expected) DUE BY \(dayNames[min(max(elapsed, 1), 7) - 1])")
        }
        let weekNum = cal.component(.weekOfYear, from: weekMonday)
        guard prevTotal > 0 else { return VSInfo(label: "VS WK \(weekNum - 1)", value: "—", color: .inkMuted, sub: "0 SETS") }
        let p = Int((Double(selectedTotalSets - prevTotal) / Double(prevTotal) * 100).rounded())
        return VSInfo(label: "VS WK \(weekNum - 1)", value: pctText(p), color: pctColor(p), sub: "\(prevTotal) SETS")
    }

    private func setCount(_ w: Workout) -> Int { w.workingSetCount }

    private func setsInWeek(offset: Int) -> Int {
        let cal = Calendar.current
        let thisMon = mondayOfThisWeek
        let mon = cal.date(byAdding: .weekOfYear, value: offset, to: thisMon)!
        let end = cal.date(byAdding: .day, value: 7, to: mon)!
        return workouts.filter { !$0.isDraft && $0.date >= mon && $0.date < end }.reduce(0) { $0 + setCount($1) }
    }

    // MARK: - Week row + day scrubber

    private var mondayOfThisWeek: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        return calendar.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: today)!
    }

    private var weekMonday: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: mondayOfThisWeek)!
    }

    private var weekRow: some View {
        let weekNumber = Calendar.current.component(.weekOfYear, from: weekMonday)
        let atOldest = weekOffset <= -(numWeeks - 1)
        let atNewest = weekOffset >= 0
        let active = selectedDayIndex == -1
        return HStack(spacing: 4) {
            Button { if !atOldest { weekOffset -= 1; selectedDayIndex = -1 } } label: {
                Text("‹").font(.spaceMono(18))
                    .foregroundStyle(atOldest ? Color.inkGhost : Color.inkPrimary)
                    .frame(width: 44, height: 44)
            }
            Button { selectedDayIndex = -1 } label: {
                HStack(spacing: 8) {
                    Text("WK \(weekNumber)").font(.spaceMono(10, weight: .bold)).tracking(1.2)
                    Text("ALL WEEK").font(.spaceMono(9)).tracking(1.2)
                        .foregroundStyle(active ? Color.canvasBg : Color.inkMuted)
                }
                .foregroundStyle(active ? Color.canvasBg : Color.inkPrimary)
                .padding(.horizontal, 14).frame(height: 32)
                .background(active ? Color.inkPrimary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(active ? Color.clear : Color.dsHairLine, lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
            Button { if !atNewest { weekOffset += 1; selectedDayIndex = -1 } } label: {
                Text("›").font(.spaceMono(18))
                    .foregroundStyle(atNewest ? Color.inkGhost : Color.inkPrimary)
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8).padding(.top, 4)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var dayScrubber: some View {
        let cal = Calendar.current
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let date = cal.date(byAdding: .day, value: i, to: weekMonday)!
                let logged = workouts.contains { !$0.isDraft && cal.isDate($0.date, inSameDayAs: date) }
                let active = selectedDayIndex == i
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedDayIndex = active ? -1 : i }
                } label: {
                    VStack(spacing: 2) {
                        Text(letters[i]).font(.spaceMono(9)).tracking(1)
                        Text("\(cal.component(.day, from: date))").font(.spaceMono(14, weight: .bold))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(logged && !active ? Color.pumpAccent.opacity(0.6) : Color.clear)
                            .frame(width: 14, height: 2)
                    }
                    .foregroundStyle(active ? Color.canvasBg : (logged ? Color.inkPrimary : Color.inkMuted))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(active ? Color.inkPrimary : Color.inkPrimary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(active ? Color.clear : Color.dsHairLine, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
    }

    // MARK: - TOP / GAPS

    private var topGaps: some View {
        HStack(alignment: .top, spacing: 16) {
            gapColumn(title: "▲ TOP", items: topMuscles, up: true)
            gapColumn(title: "▼ GAPS", items: gapMuscles, up: false)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 14)
    }

    private func gapColumn(title: String, items: [MuscleItem], up: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.spaceMono(9)).tracking(1.5)
                Spacer()
                Text("SETS / TARGET").font(.spaceMono(7)).tracking(1)
            }
            .foregroundStyle(Color.inkMuted)
            .frame(height: 28)
            ForEach(items) { m in
                HStack(spacing: 6) {
                    Text(m.key).font(.spaceMono(10, weight: .bold)).tracking(0.8)
                        .foregroundStyle(Color.inkPrimary).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(m.sets)").font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        Text("/\(m.target)").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                    }
                    Text("\(up ? "▲" : "▼") \(Int(m.ratio * 100))%")
                        .font(.spaceMono(9))
                        .foregroundStyle(up ? Color.signalUp : Color.signalDown)
                        .frame(width: 46, alignment: .trailing)
                }
                .frame(height: 44)
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cold Spots

    private struct ColdSpotItem: Identifiable {
        let id = UUID()
        let muscleName: String
        let value: Int
        let target: Int
        let isFlagged: Bool
        var ratio: Double { Double(value) / Double(max(target, 1)) }
    }

    private var coldSpotsSection: some View {
        let spots = coldSpotsData
        let flagged = spots.filter { $0.isFlagged }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(coldSpotsMode == .freq ? "COLD SPOTS · \(flagged) STALE" : "UNDER TARGET · \(flagged) LOW")
                    .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(ColdSpotsMode.allCases, id: \.self) { m in
                    chip(m.rawValue, active: coldSpotsMode == m) { coldSpotsMode = m }
                }
            }
            HStack(spacing: 8) {
                ForEach(spots) { coldSpotCard($0) }
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 20)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var coldSpotsData: [ColdSpotItem] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        if coldSpotsMode == .freq {
            return Self.tracked.map { muscle in
                var latest: Date? = nil
                for log in exerciseLogs {
                    guard let ex = log.exercise, let w = log.workout, !w.isDraft else { continue }
                    let hit = (ex.primaryMuscleGroups + ex.secondaryMuscleGroups).contains { tracked($0) == muscle }
                    if hit, latest == nil || w.date > latest! { latest = w.date }
                }
                let days = latest.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: Date())).day ?? 0 } ?? 99
                let cad = Self.cadence[muscle] ?? 4
                return ColdSpotItem(muscleName: muscle.displayName, value: days, target: cad,
                                    isFlagged: days >= Int(Double(cad) * 1.5))
            }
            .sorted { Double($0.value) / Double($0.target) > Double($1.value) / Double($1.target) }
            .prefix(3).map { $0 }
        }
        var setsByMuscle: [MuscleGroup: Int] = [:]
        for log in exerciseLogs {
            guard let ex = log.exercise, let w = log.workout, !w.isDraft, w.date >= weekAgo else { continue }
            for m in ex.primaryMuscleGroups { if let t = tracked(m) { setsByMuscle[t, default: 0] += log.workingSets.count } }
            for m in ex.secondaryMuscleGroups { if let t = tracked(m) { setsByMuscle[t, default: 0] += log.workingSets.count / 2 } }
        }
        return Self.tracked.map { muscle in
            let sets = setsByMuscle[muscle] ?? 0
            let tgt = Self.targets[muscle] ?? 10
            return ColdSpotItem(muscleName: muscle.displayName, value: sets, target: tgt,
                                isFlagged: Double(sets) / Double(tgt) < 0.5)
        }
        .sorted { $0.ratio < $1.ratio }
        .prefix(3).map { $0 }
    }

    private func coldSpotCard(_ spot: ColdSpotItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(spot.muscleName.uppercased())
                .font(.spaceMono(9, weight: .bold)).tracking(0.8)
                .foregroundStyle(Color.inkPrimary).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(coldSpotsMode == .freq ? "\(spot.value)D" : "\(spot.value)")
                    .font(.spaceMono(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Text(coldSpotsMode == .freq ? "/ \(spot.target)D" : "/ \(spot.target)")
                    .font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.dsHairLine).frame(height: 2)
                    Rectangle()
                        .fill(spot.isFlagged ? Color.signalDown : Color.inkPrimary.opacity(0.7))
                        .frame(width: geo.size.width * min(spot.ratio, 1.0), height: 2)
                }
            }
            .frame(height: 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Calendar sheet  (same calendar as More › History)

    private struct CalDay { let date: Date?; let day: Int? }

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
        let isToday = day.date.map { calendar.isDateInToday($0) } ?? false
        let isFuture = day.date.map { calendar.startOfDay(for: $0) > calendar.startOfDay(for: Date()) } ?? false
        let hasWorkout = !isFuture && (day.date.map { d in workouts.contains { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: d) } } ?? false)

        let bg: Color = isSelected ? Color.pumpAccent : hasWorkout ? Color.accentSoft : .clear
        let border: Color = isSelected ? Color.pumpAccent
            : isToday ? Color.pumpAccent
            : hasWorkout ? Color.accentInk.opacity(0.25)
            : (isFuture || day.date == nil) ? .clear : Color.dsHairLine
        let borderWidth: CGFloat = (isToday && !isSelected) ? 1.5 : 1
        let fg: Color = isSelected ? .white
            : (hasWorkout || isToday) ? Color.accentInk
            : isFuture ? Color.inkGhost : Color.inkMuted

        return Button {
            guard let date = day.date, hasWorkout else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                selectedCalendarDate = isSelected ? nil : date
                sheetDetent = selectedCalendarDate != nil ? .height(560) : .height(440)
            }
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(bg)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(border, lineWidth: borderWidth))
                .overlay {
                    if let d = day.day {
                        VStack(spacing: 2) {
                            Text("\(d)").font(.spaceMono(11, weight: (isSelected || hasWorkout || isToday) ? .bold : .regular))
                                .foregroundStyle(fg)
                            Circle().fill(isSelected ? Color.white : hasWorkout ? Color.pumpAccent : .clear)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(day.date == nil || !hasWorkout)
    }

    private var calendarSheet: some View {
        let calendar = Calendar.current
        let canGoNext = calendar.date(byAdding: .month, value: 1, to: calendarMonth)! <= Date()
        let earliest = workouts.filter { !$0.isDraft }.map(\.date).min() ?? Date()
        let canGoPrev = calendar.date(byAdding: .month, value: -1, to: calendarMonth)! >= calendar.date(from: calendar.dateComponents([.year, .month], from: earliest))!
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let days = calendarDays()

        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Button { withAnimation(.easeInOut(duration: 0.2)) { if canGoPrev { calendarMonth = calendar.date(byAdding: .month, value: -1, to: calendarMonth)! } } } label: {
                        Text("‹").font(.spaceMono(18)).foregroundStyle(canGoPrev ? Color.inkMuted : Color.inkGhost)
                            .frame(width: 44, height: 44)
                    }
                    Text(df.string(from: calendarMonth).uppercased())
                        .font(.archivo(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity)
                    Button { withAnimation(.easeInOut(duration: 0.2)) { if canGoNext { calendarMonth = calendar.date(byAdding: .month, value: 1, to: calendarMonth)! } } } label: {
                        Text("›").font(.spaceMono(18)).foregroundStyle(canGoNext ? Color.inkMuted : Color.inkGhost)
                            .frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)

                HStack(spacing: 0) {
                    ForEach(Array(["M","T","W","T","F","S","S"].enumerated()), id: \.offset) { _, d in
                        Text(d).font(.spaceMono(9)).tracking(0.8).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 6)

                LazyVGrid(columns: cols, spacing: 4) {
                    ForEach(0..<42, id: \.self) { i in
                        if i < days.count { calCell(days[i]) } else { Color.clear.aspectRatio(1, contentMode: .fit) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 14)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            if let date = selectedCalendarDate {
                calendarDayDetail(for: date)
                    .padding(.top, 14)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func calendarDayDetail(for date: Date) -> some View {
        let calendar = Calendar.current
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f }()
        let workout = workouts.first { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: date) }
        let sets = workout.map(setCount) ?? 0
        let mins = Int(workout?.duration ?? 0) / 60
        let secs = Int(workout?.duration ?? 0) % 60

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(df.string(from: date).uppercased()).font(.spaceMono(8)).tracking(1.3).foregroundStyle(Color.inkMuted)
                Text(workout?.template?.name ?? "Workout").font(.archivo(20, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Text("\(sets) SETS · \(mins):\(String(format: "%02d", secs))").font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                let cal = Calendar.current
                let selWD = cal.component(.weekday, from: date)
                let selMon = cal.date(byAdding: .day, value: -(selWD == 1 ? 6 : selWD - 2), to: cal.startOfDay(for: date))!
                let weekDiff = cal.dateComponents([.weekOfYear], from: selMon, to: mondayOfThisWeek).weekOfYear ?? 0
                weekOffset = max(-(numWeeks - 1), -weekDiff)
                selectedDayIndex = selWD == 1 ? 6 : selWD - 2
                showCalendar = false
            } label: {
                Text("VIEW ›").font(.archivo(13, weight: .black)).tracking(1.5).foregroundStyle(.white)
                    .padding(.horizontal, 18).frame(height: 44)
                    .background(Color.pumpAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
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
        }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: monday) else { return exerciseLogs }
        return exerciseLogs.filter { log in
            guard let workout = log.workout, !workout.isDraft else { return false }
            return workout.date >= monday && workout.date < weekEnd
        }
    }

    private var selectedTotalSets: Int { filteredLogs.reduce(0) { $0 + $1.workingSets.count } }

    private var selectedDayLabel: String {
        let calendar = Calendar.current
        let df = DateFormatter(); df.dateFormat = "MMM d"
        if selectedDayIndex >= 0 {
            let dayNames = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            let date = calendar.date(byAdding: .day, value: selectedDayIndex, to: weekMonday)!
            let workout = workouts.first { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: date) }
            let name = workout?.template?.name.uppercased() ?? (workout != nil ? "WORKOUT" : "REST")
            return "\(dayNames[selectedDayIndex]) · \(df.string(from: date).uppercased()) · \(name)"
        }
        let weekNum = calendar.component(.weekOfYear, from: weekMonday)
        let sunday = calendar.date(byAdding: .day, value: 6, to: weekMonday)!
        let sameMonth = calendar.component(.month, from: weekMonday) == calendar.component(.month, from: sunday)
        let end = sameMonth ? "\(calendar.component(.day, from: sunday))" : df.string(from: sunday).uppercased()
        return "WEEK \(weekNum) · \(df.string(from: weekMonday).uppercased())–\(end)"
    }

    private var musclesWorkedCount: Int {
        var muscles = Set<MuscleGroup>()
        for log in filteredLogs {
            guard let exercise = log.exercise else { continue }
            for m in exercise.primaryMuscleGroups { if let t = tracked(m) { muscles.insert(t) } }
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

    private var setsByMuscle: [MuscleGroup: Int] {
        var out: [MuscleGroup: Int] = [:]
        for log in filteredLogs {
            guard let exercise = log.exercise else { continue }
            for m in exercise.primaryMuscleGroups { if let t = tracked(m) { out[t, default: 0] += log.workingSets.count } }
        }
        return out
    }

    private var muscleSetsData: [MuscleItem] {
        let sets = setsByMuscle
        return Self.tracked.map { MuscleItem(key: Self.abbr[$0] ?? $0.displayName.uppercased(),
                                             sets: sets[$0] ?? 0, target: Self.targets[$0] ?? 10) }
            .sorted { $0.ratio > $1.ratio }
    }

    private var topMuscles: [MuscleItem] { Array(muscleSetsData.prefix(3)) }
    private var gapMuscles: [MuscleItem] { Array(muscleSetsData.suffix(3).reversed()) }

    /// Heat intensity per group — VOLUME (sets vs target / vs the day's peak) or LAST 48H (recency fade).
    private var heatLevels: [MuscleGroup: Double] {
        var levels: [MuscleGroup: Double] = [:]
        if heatmapMode == .recency {
            let cal = Calendar.current
            let end: Date = selectedDayIndex >= 0
                ? cal.date(byAdding: .day, value: selectedDayIndex, to: weekMonday)!
                : min(cal.date(byAdding: .day, value: 6, to: weekMonday)!, cal.startOfDay(for: Date()))
            let now = cal.date(byAdding: .hour, value: 21, to: end)!
            for m in Self.tracked {
                var last: Date?
                for log in exerciseLogs {
                    guard let ex = log.exercise, let w = log.workout, !w.isDraft, w.date <= now else { continue }
                    if ex.primaryMuscleGroups.contains(where: { tracked($0) == m }), last == nil || w.date > last! { last = w.date }
                }
                if let last { levels[m] = max(0, 1 - now.timeIntervalSince(last) / (48 * 3600)) }
            }
            return levels
        }
        let sets = setsByMuscle
        let peak = Double(max(sets.values.max() ?? 1, 1))
        for m in Self.tracked {
            let v = Double(sets[m] ?? 0)
            levels[m] = selectedDayIndex >= 0 ? v / peak : min(1, v / Double(Self.targets[m] ?? 10))
        }
        return levels
    }

    // MARK: - Ticker

    private func daysSince(workoutNamed name: String) -> String {
        let cal = Calendar.current
        guard let w = workouts.filter({ !$0.isDraft && ($0.template?.name.uppercased().contains(name) ?? false) })
            .max(by: { $0.date < $1.date }) else { return "—" }
        return "\(cal.dateComponents([.day], from: cal.startOfDay(for: w.date), to: cal.startOfDay(for: Date())).day ?? 0)D"
    }

    private var tickerItems: [TickerItem] {
        guard !workouts.isEmpty else { return [] }
        let vs = vsInfo
        let vsDir: TickerItem.Direction? = vs.value.contains("▲") ? .up : vs.value.contains("▼") ? .down : nil
        let prev = setsInWeek(offset: -1), prev2 = setsInWeek(offset: -2)
        let wkP = prev2 > 0 ? Int((Double(prev - prev2) / Double(prev2) * 100).rounded()) : 0
        let weekNum = Calendar.current.component(.weekOfYear, from: mondayOfThisWeek) - 1
        var items: [TickerItem] = [
            TickerItem(label: vs.label.hasPrefix("VS PACE") ? "VS PACE" : "VS LAST",
                       value: vs.value.replacingOccurrences(of: "▲ ", with: "").replacingOccurrences(of: "▼ ", with: "").replacingOccurrences(of: "● ", with: ""),
                       direction: vsDir),
            TickerItem(label: "WK\(weekNum)", value: "\(abs(wkP))%", direction: wkP >= 0 ? .up : .down),
        ]
        items += topMuscles.map { TickerItem(label: $0.key, value: "\(Int($0.ratio * 100))%", direction: .up) }
        items += gapMuscles.map { TickerItem(label: $0.key, value: "\(Int($0.ratio * 100))%", direction: .down) }
        items += [TickerItem(label: "PUSH", value: daysSince(workoutNamed: "PUSH"), direction: nil),
                  TickerItem(label: "PULL", value: daysSince(workoutNamed: "PULL"), direction: nil),
                  TickerItem(label: "LEGS", value: daysSince(workoutNamed: "LEG"), direction: nil)]
        return items + items
    }
}
