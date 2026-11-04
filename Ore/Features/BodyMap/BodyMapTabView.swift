import SwiftUI
import SwiftData

// MARK: - Body tab (Ore Body Final): Volume | Frequency* lenses, week + day strip, front/back map, muscle tree, shared calendar modal

/// What the muscle tree has focused: the map shows only those muscles.
struct BodyFocus: Equatable {
    let key: String
    let label: String
    let ids: Set<String>
}

struct BodyMapTabView: View {
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil }) private var workouts: [Workout]
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }) private var templates: [WorkoutTemplate]
    @Environment(\.colorScheme) private var scheme
    @State private var lens: BodyLens = .volume
    @State private var weekOffset = 0
    @State private var dayIndex: Int? = nil
    @State private var mainSide: BodySide = .front
    @State private var focus: BodyFocus?
    @State private var openGroups: Set<String> = []
    @State private var openMuscles: Set<String> = []
    @State private var showCalendar = false
    @State private var calendarSelection: CalendarSelection = .none
    @State private var replay = 0
    @State private var calData: WorkoutCalendarData?
    @State private var calKey = ""
    #if DEBUG
    @State private var showMapPanel = false
    @State private var debugPreset: Int? = UserDefaults.standard.string(forKey: "debugBodyMapPreset").flatMap(Int.init)
    @State private var debugMember: Bool? = UserDefaults.standard.string(forKey: "debugBodyMapMember").map { $0 == "1" }
    #endif

    typealias BodySide = BodyMapSide

    private var member: Bool {
        #if DEBUG
        if let m = debugMember { return m }
        #endif
        return AccentStore.shared.isMember
    }

    private var stats: BodyPageStats {
        BodyPageStats(workouts: workouts, weekOffset: weekOffset, dayIndex: dayIndex, plan: { calData?.plan(on: $0) })
    }

    private var locked: Bool { lens == .frequency && !member }

    // MARK: Body

    var body: some View {
        let s = stats
        ZStack {
            VStack(spacing: 0) {
                OreMasthead(markID: AX.body.screen) {
                    Button { openCalendar(s) } label: {
                        CalendarGlyph().stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                            .frame(width: 20, height: 20).foregroundStyle(Color.inkPrimary)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.ruleStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Calendar").accessibilityIdentifier(AX.body.calendar)
                }
                let items = s.tickerItems(member: member)
                if !items.isEmpty { TickerStripView(items: items) }
                ScrollView {
                    VStack(spacing: 0) {
                        titleRow(s)
                        if lens == .volume { weekNav(s); dayStrip(s) }
                        legend
                        mapArea(s)
                        if !locked { statsStrip(s); tree(s) }
                        Color.clear.frame(height: 20)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Color.canvasBg.ignoresSafeArea())
            calendarModal(s)
        }
        .onAppear { refreshCalendarData() }
        .onChange(of: workouts.count) { _, _ in refreshCalendarData() }
        .onChange(of: templates.count) { _, _ in refreshCalendarData() }
        .onChange(of: focus) { _, new in
            if let new, let side = Self.autoSide(for: new.ids) { mainSide = side }
        }
        .onChange(of: lens) { _, _ in focus = nil; replay += 1 }
    }

    private func refreshCalendarData() {
        let key = "\(workouts.count)|\(templates.count)"
        guard key != calKey else { return }
        calKey = key
        calData = WorkoutCalendarData(workouts: workouts, templates: templates)
    }

    /// When every focused muscle is only on one side, that side becomes the main view.
    static func autoSide(for ids: Set<String>) -> BodySide? {
        guard !ids.isEmpty else { return nil }
        let backOnly = BodyMapLevels.backIds.subtracting(BodyMapLevels.frontIds)
        let frontOnly = BodyMapLevels.frontIds.subtracting(BodyMapLevels.backIds)
        if ids.isSubset(of: backOnly) { return .back }
        if ids.isSubset(of: frontOnly) { return .front }
        return nil
    }

    // MARK: Title + lens switch

    private func titleRow(_ s: BodyPageStats) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(rangeText(s)).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                Text("BODY").font(.archivo(30, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                lensOption("VOLUME", .volume, id: AX.body.modeVolume, star: false)
                lensOption("FREQUENCY", .frequency, id: AX.body.modeFrequency, star: true)
            }
            .padding(3).background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func rangeText(_ s: BodyPageStats) -> String {
        if lens == .frequency { return "LAST \(Int(BodyPageConfig.windowHours)) HOURS" }
        guard let i = dayIndex else { return s.weekLabel }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: s.date(ofDay: i)).uppercased()
    }

    private func lensOption(_ title: String, _ value: BodyLens, id: String, star: Bool) -> some View {
        let on = lens == value
        return Button { withAnimation(.easeInOut(duration: 0.15)) { lens = value } } label: {
            HStack(spacing: 1) {
                Text(title).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                if star { Text("*").font(.archivo(12, weight: .black)).foregroundStyle(SupernovaAsterisk.color) }
            }
            .foregroundStyle(on ? Color.inkPrimary : Color.inkMuted)
            .padding(.horizontal, 10).frame(height: 30)
            .background(on ? (scheme == .dark ? Color.surf : Color.white) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }

    // MARK: Week nav + day strip

    private func weekNav(_ s: BodyPageStats) -> some View {
        HStack(spacing: 6) {
            navArrow("‹", enabled: s.canGoBack, id: AX.body.prevWeek) { weekOffset -= 1; dayIndex = nil; focus = nil; replay += 1 }
            VStack(spacing: 3) {
                Text(s.weekLabel).font(.spaceMono(13, weight: .bold)).tracking(1).foregroundStyle(Color.inkPrimary)
                Text(s.relativeLabel).font(.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity)
            navArrow("›", enabled: s.canGoForward, id: AX.body.nextWeek) { weekOffset += 1; dayIndex = nil; focus = nil; replay += 1 }
        }
        .padding(.horizontal, 10).padding(.top, 8)
    }

    private func navArrow(_ glyph: String, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(.archivo(22)).foregroundStyle(enabled ? Color.inkPrimary : Color.inkPrimary.opacity(scheme == .dark ? 0.18 : 0.13))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).disabled(!enabled)
        .accessibilityLabel(glyph == "‹" ? "Previous week" : "Next week").accessibilityIdentifier(id)
    }

    private func dayStrip(_ s: BodyPageStats) -> some View {
        let counts = s.daySets
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let todayIndex: Int? = s.weekOffset == 0 ? s.target(for: s.now).dayIndex : nil
        return HStack(spacing: 4) {
            stripTile("WEEK", counts.reduce(0, +), selected: dayIndex == nil, today: false, id: AX.body.allWeek, grow: 1.3) { dayIndex = nil; focus = nil; replay += 1 }
            ForEach(0..<7, id: \.self) { i in
                stripTile(letters[i], counts[i], selected: dayIndex == i, today: todayIndex == i, id: AX.body.day(i), grow: 1) {
                    dayIndex = dayIndex == i ? nil : i; focus = nil; replay += 1
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 4)
    }

    private func stripTile(_ label: String, _ sets: Int, selected: Bool, today: Bool, id: String, grow: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label).font(.spaceMono(7)).tracking(1).foregroundStyle(selected ? Color.white.opacity(0.9) : Color.inkMuted)
                Text(sets > 0 ? "\(sets)" : "—").font(.spaceMono(12, weight: .bold))
                    .foregroundStyle(selected ? Color.white : sets > 0 ? Color.inkPrimary : Color.inkMuted)
            }
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(selected ? Color.oreAccent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.clear : today ? Color.oreAccent : Color.dsHairLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .layoutPriority(grow)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(id)
    }

    // MARK: Legend + map

    private var legend: some View {
        let freq = lens == .frequency
        return HStack(spacing: 8) {
            Text(freq ? "LAST TRAINED" : "SETS VS TARGET").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            Spacer(minLength: 0)
            Text(freq ? "\(Int(BodyPageConfig.windowHours))H" : "0%").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            HStack(spacing: 2) {
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { g in
                    RoundedRectangle(cornerRadius: 2).fill(Color.oreAccent.opacity(g)).frame(width: 14, height: 8)
                }
            }
            Text(freq ? "NOW" : "100%").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 16).padding(.top, 10)
        .opacity(locked ? 0.35 : 1)
    }

    private func mapLevels(_ s: BodyPageStats) -> [String: Double] {
        #if DEBUG
        if let i = debugPreset { return BodyMapDevPanel.presets[i].1 }
        #endif
        var levels = lens == .volume ? s.volumeLevels : s.frequencyLevels
        if let focus { levels = levels.filter { focus.ids.contains($0.key) } }
        return levels
    }

    private func mapArea(_ s: BodyPageStats) -> some View {
        let levels = mapLevels(s)
        let other: BodySide = mainSide == .front ? .back : .front
        return BodyFigureView(side: mainSide, levels: levels, member: member && !locked, accentHex: AccentStore.shared.active.hexString, replay: replay)
            .accessibilityIdentifier(mainSide == .front ? AX.body.figureFront : AX.body.figureBack)
            #if DEBUG
            .onLongPressGesture { showMapPanel = true }
            .sheet(isPresented: $showMapPanel) {
                BodyMapDevPanel(presetIndex: $debugPreset, memberOverride: $debugMember) { replay += 1 }.presentationDetents([.medium])
            }
            #endif
            .padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: 370)
            .opacity(locked ? 0.35 : 1)
            // Corner tile: the other side, tap to swap.
            .overlay(alignment: .bottomTrailing) {
                Button { withAnimation(.easeInOut(duration: 0.2)) { mainSide = other } } label: {
                    VStack(spacing: 0) {
                        BodyFigureView(side: other, levels: levels, member: false, accentHex: AccentStore.shared.active.hexString, replay: replay)
                            .allowsHitTesting(false).frame(maxHeight: .infinity).padding(.top, 6)
                        Text(other.rawValue.uppercased()).font(.spaceMono(7)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.bottom, 4)
                    }
                    .frame(width: 76, height: 112).background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain).opacity(locked ? 0.35 : 1)
                .accessibilityLabel("Show \(other.rawValue) view").accessibilityIdentifier(AX.body.mapSwap)
                .padding(.trailing, 16)
            }
            .overlay(alignment: .topLeading) {
                if let focus, !locked {
                    Button { self.focus = nil } label: {
                        HStack(spacing: 6) {
                            Text(focus.label.uppercased()).font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
                            Text("×").foregroundStyle(Color.inkMuted)
                        }
                        .padding(.horizontal, 10).frame(height: 28).background(Color.surf2).clipShape(Capsule())
                    }
                    .buttonStyle(.plain).padding(.leading, 16).padding(.top, 6).accessibilityIdentifier(AX.body.focusChip)
                }
            }
            .overlay(alignment: .top) {
                if lens == .volume, let note = s.dayNote {
                    Text(note).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(18)
                        .background(Color.canvasBg).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .padding(.horizontal, 24).padding(.top, 140).accessibilityIdentifier(AX.body.dayNote)
                }
            }
            .overlay(alignment: .top) { if locked { lockedCard } }
            .padding(.top, 4)
    }

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("FREQUENCY · SUPERNOVA").font(.spaceMono(9, weight: .bold)).tracking(2).foregroundStyle(Color.inkPrimary)
                Text("*").font(.archivo(13, weight: .black)).foregroundStyle(SupernovaAsterisk.color)
            }
            Text("See which muscles you've trained in the last \(Int(BodyPageConfig.windowHours)) hours and which are due.")
                .font(.archivo(13)).foregroundStyle(Color.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Button { SupernovaTransition.shared.open(.paywall, fromSource: false) } label: {
                HStack {
                    HStack(spacing: 0) { Text("GO SUPERNOVA").font(.archivo(14, weight: .black)).tracking(0.6); Text("*").foregroundStyle(SupernovaAsterisk.color) }
                    Spacer(minLength: 0)
                    Text("›").font(.archivo(14, weight: .black))
                }
                .foregroundStyle(Color.inkPrimary).padding(.horizontal, 14).frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.body.lockedCTA)
        }
        .padding(16).background(Color.surf).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ruleStrong, lineWidth: 1))
        .padding(.horizontal, 24).padding(.top, 110).accessibilityElement(children: .contain).accessibilityIdentifier(AX.body.locked)
    }

    // MARK: Stats strip

    private func statsStrip(_ s: BodyPageStats) -> some View {
        let cells: [(String, String, String, CGFloat, String?)]
        if lens == .volume {
            cells = [("SETS", "\(s.workoutSets)", "", 22, AX.body.totalSets), ("GROUPS HIT", "\(s.groupsHit)", "/\(BodyMuscleTree.groups.count)", 22, AX.body.statGroups),
                     ("MUSCLES HIT", "\(s.musclesHit)", "/\(s.muscleCount)", 22, AX.body.statMuscles)]
        } else {
            let next = s.nextDue
            cells = [("IN WINDOW", "\(s.inWindowCount)", "/\(s.muscleCount)", 22, nil), ("DUE NOW", "\(s.dueCount)", "", 22, nil),
                     ("NEXT DUE", next.map { $0.name.uppercased() } ?? "—", next.map { "\($0.hoursLeft)H" } ?? "", 13, nil)]
        }
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                VStack(alignment: .leading, spacing: 8) {
                    Text(c.0).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(c.1).font(.spaceMono(c.3, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1).minimumScaleFactor(0.7)
                            .accessibilityIdentifier(c.4 ?? "body.stat.\(i)")
                        Text(c.2).font(.spaceMono(11)).foregroundStyle(Color.inkMuted).lineLimit(1)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { if i > 0 { Rectangle().fill(Color.dsHairLine).frame(width: 1) } }
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .padding(.top, 12)
    }

    // MARK: Muscle tree

    private struct TreeRow: Identifiable {
        enum Kind { case group, muscle, head }
        let id: String
        let kind: Kind
        let name: String
        let hasChildren: Bool
        let open: Bool
        let sets: Int
        let weekly: Int
        let ids: Set<String>
        let fresh: BodyPageStats.Freshness
        let count: (inWindow: Int, total: Int)?
    }

    private func rows(_ s: BodyPageStats) -> [TreeRow] {
        let t = s.tally, last = s.lastTrainedById
        var out: [TreeRow] = []
        for g in BodyMuscleTree.groups {
            let muscleFresh = g.muscles.map { s.freshness(of: $0, last: last) }
            out.append(TreeRow(id: g.id, kind: .group, name: g.name, hasChildren: true, open: openGroups.contains(g.id), sets: t.group[g.id] ?? 0,
                               weekly: g.target, ids: Set(g.ids), fresh: s.freshness(of: g, last: last),
                               count: (muscleFresh.filter(\.inWindow).count, g.muscles.count)))
            guard openGroups.contains(g.id) else { continue }
            for m in g.muscles {
                let heads = !m.heads.isEmpty
                out.append(TreeRow(id: m.id, kind: .muscle, name: m.name, hasChildren: heads, open: openMuscles.contains(m.id), sets: t.muscle[m.id] ?? 0,
                                   weekly: m.target, ids: Set(m.ids), fresh: s.freshness(of: m, last: last), count: nil))
                guard heads, openMuscles.contains(m.id) else { continue }
                for h in m.heads {
                    out.append(TreeRow(id: h.id, kind: .head, name: h.name, hasChildren: false, open: false, sets: t.head[h.id] ?? 0, weekly: h.target,
                                       ids: [h.id], fresh: s.freshness(of: h, last: last), count: nil))
                }
            }
        }
        return out
    }

    private func tree(_ s: BodyPageStats) -> some View {
        let freq = lens == .frequency
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("MUSCLE").frame(maxWidth: .infinity, alignment: .leading)
                Text(freq ? "LAST" : "SETS").frame(width: 92, alignment: .trailing)
                Text(freq ? "WINDOW" : "VS TARGET").frame(width: 64, alignment: .leading)
            }
            .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 16).padding(.vertical, 8).background(Color.surf2).padding(.top, 16)
            ForEach(rows(s)) { r in treeRow(r, s, freq: freq) }
            Text(freq ? "In the window means trained in the last \(Int(BodyPageConfig.windowHours)) hours. Due means it is past that."
                      : "Targets are weekly working sets for each muscle. A single day is measured against half of it.")
                .font(.archivo(12)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 12)
        }
    }

    private func treeRow(_ r: TreeRow, _ s: BodyPageStats, freq: Bool) -> some View {
        let height: CGFloat = r.kind == .group ? 48 : r.kind == .muscle ? 42 : 36
        let pad: CGFloat = r.kind == .group ? 16 : r.kind == .muscle ? 28 : 40
        let focused = focus?.key == r.id
        let chev = r.kind == .group ? (r.open ? "▾" : "▸") : r.hasChildren ? (r.open ? "▾" : "›") : ""
        let font: Font = r.kind == .group ? .archivo(16, weight: .bold) : r.kind == .muscle ? .archivo(14, weight: .semibold) : .archivo(13)
        let ratio = s.ratio(sets: r.sets, weeklyTarget: r.weekly)
        return Button { tap(r) } label: {
            HStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(chev).font(.spaceMono(11, weight: .bold)).foregroundStyle(Color.inkMuted).frame(width: 12).padding(.top, 7)
                    Text(r.kind == .group ? r.name.uppercased() : r.name).font(font).lineSpacing(0)
                        .foregroundStyle(Color.inkPrimary).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                        .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    if freq {
                        if r.kind == .group, let c = r.count {
                            (Text("\(c.inWindow)").font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkPrimary)
                             + Text(" / \(c.total)").font(.spaceMono(12)).foregroundStyle(Color.inkMuted))
                        } else {
                            Text(BodyPageStats.agoText(hours: r.fresh.hours)).font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkPrimary).lineLimit(1)
                            if r.fresh.isDue {
                                Text("DUE").font(.spaceMono(7, weight: .bold)).tracking(1).foregroundStyle(Color.inkPrimary)
                                    .padding(.horizontal, 5).frame(height: 18)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.inkPrimary, lineWidth: 1))
                            }
                        }
                    } else {
                        (Text("\(r.sets)").font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.inkPrimary)
                         + Text(" / \(s.targetText(r.weekly))").font(.spaceMono(12)).foregroundStyle(Color.inkMuted))
                    }
                }
                .frame(width: 92, alignment: .trailing)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.surf2)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3).fill(Color.oreAccent)
                            .frame(width: geo.size.width * (freq ? (r.kind == .group ? Double(r.count?.inWindow ?? 0) / Double(max(1, r.count?.total ?? 1)) : r.fresh.windowLeft) : ratio))
                    }
                }
                .frame(width: 64, height: 6)
            }
            .padding(.leading, pad).padding(.trailing, 16)
            .frame(minHeight: height)
            .background(focused ? Color.surf : Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.body.row(r.id))
    }

    private func tap(_ r: TreeRow) {
        withAnimation(.easeInOut(duration: 0.15)) {
            switch r.kind {
            case .group:
                if openGroups.contains(r.id) { openGroups.remove(r.id); if focus?.key == r.id { focus = nil } }
                else { openGroups.insert(r.id); focus = BodyFocus(key: r.id, label: r.name, ids: r.ids) }
            case .muscle:
                if r.hasChildren {
                    if openMuscles.contains(r.id) { openMuscles.remove(r.id); if focus?.key == r.id { focus = nil } }
                    else { openMuscles.insert(r.id); focus = BodyFocus(key: r.id, label: r.name, ids: r.ids) }
                } else {
                    focus = focus?.key == r.id ? nil : BodyFocus(key: r.id, label: r.name, ids: r.ids)
                }
            case .head:
                focus = focus?.key == r.id ? nil : BodyFocus(key: r.id, label: r.name, ids: r.ids)
            }
        }
    }

    // MARK: Calendar modal

    private func openCalendar(_ s: BodyPageStats) {
        calendarSelection = dayIndex.map { .day(s.date(ofDay: $0)) } ?? .week(s.weekMonday)
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) { showCalendar = true }
    }

    private func closeCalendar() { withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) { showCalendar = false } }

    private func showOnMap(_ selection: CalendarSelection, _ s: BodyPageStats) {
        switch selection {
        case .day(let d): let t = s.target(for: d); weekOffset = t.weekOffset; dayIndex = t.dayIndex
        case .week(let w): weekOffset = s.target(for: w).weekOffset; dayIndex = nil
        case .none: break
        }
        lens = .volume; focus = nil; replay += 1
        closeCalendar()
    }

    /// Centred card over a dimmed backdrop (never blurred): scales 0.96 → 1 with a fade over 350 ms. Not in the hierarchy while closed,
    /// so nothing invisible sits over the page.
    @ViewBuilder
    private func calendarModal(_ s: BodyPageStats) -> some View {
        if showCalendar {
            ZStack {
                Color(red: 21 / 255, green: 26 / 255, blue: 33 / 255).opacity(0.35).ignoresSafeArea()
                    .onTapGesture { closeCalendar() }
                    .transition(.opacity)
                VStack(spacing: 0) {
                    HStack {
                        Text("CALENDAR").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        Spacer(minLength: 0)
                        Button { closeCalendar() } label: {
                            Text("×").font(.archivo(20)).foregroundStyle(Color.inkSecondary).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Close calendar").accessibilityIdentifier(AX.calendar.close)
                    }
                    .padding(.leading, 16).padding(.trailing, 8).padding(.top, 8)
                    if let calData {
                        OreCalendarView(mode: .modal, source: calData, selection: $calendarSelection, cardAction: .showOnMap,
                                        initialMonth: s.weekMonday, onShowOnMap: { showOnMap($0, s) })
                    }
                }
                .background(Color.canvasBg).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ruleStrong, lineWidth: 1))
                .padding(.horizontal, 12)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .accessibilityElement(children: .contain).accessibilityIdentifier(AX.calendar.modal)
            }
        }
    }
}

/// The calendar button's icon, the same Lucide calendar the History switch draws.
struct CalendarGlyph: Shape {
    func path(in r: CGRect) -> Path { HistoryCalendarIcon().path(in: r) }
}
