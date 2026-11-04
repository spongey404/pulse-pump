import SwiftUI

/// The calendar used by History (fullscreen) and Body (modal): month nav, Monday-first grid with a week-number column, and the card area.
/// All rules are in `OreCalendarLogic`; this only draws them (Ore History Calendar Final).
struct OreCalendarView: View {
    enum Mode { case fullscreen, modal }

    var mode: Mode = .fullscreen
    let source: CalendarDataSource
    @Binding var selection: CalendarSelection
    var cardAction: CalendarCardAction = .openWorkout
    var onSelect: (CalendarSelection) -> Void = { _ in }
    var onOpenWorkout: (CalendarSession) -> Void = { _ in }
    var onShowOnMap: (CalendarSelection) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme
    @State private var month: Date

    init(mode: Mode = .fullscreen, source: CalendarDataSource, selection: Binding<CalendarSelection>, cardAction: CalendarCardAction = .openWorkout,
         initialMonth: Date = Date(), onSelect: @escaping (CalendarSelection) -> Void = { _ in },
         onOpenWorkout: @escaping (CalendarSession) -> Void = { _ in }, onShowOnMap: @escaping (CalendarSelection) -> Void = { _ in }) {
        self.mode = mode; self.source = source; self._selection = selection; self.cardAction = cardAction
        self.onSelect = onSelect; self.onOpenWorkout = onOpenWorkout; self.onShowOnMap = onShowOnMap
        _month = State(initialValue: initialMonth)
    }

    private var logic: OreCalendarLogic { OreCalendarLogic(source: source) }
    private var ghost: Color { Color.inkPrimary.opacity(scheme == .dark ? 0.18 : 0.13) }   // --text-ghost
    private var tint: Color { Color.oreAccent.opacity(scheme == .dark ? 0.16 : 0.10) }

    var body: some View {
        let l = logic
        VStack(spacing: 0) {
            nav(l)
            weekdayHeader
            grid(l)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
            cardArea(l)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier(AX.calendar.root)
        .onAppear { month = l.shift(month, by: 0) }
    }

    // MARK: Month nav

    private func nav(_ l: OreCalendarLogic) -> some View {
        HStack(spacing: 0) {
            arrow("‹", enabled: l.canGoBack(from: month), id: AX.calendar.prev) { month = l.shift(month, by: -1) }
            Text(l.title(of: month))
                .font(.archivo(22, weight: .black)).tracking(0.3)
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AX.calendar.title)
            arrow("›", enabled: l.canGoForward(from: month), id: AX.calendar.next) { month = l.shift(month, by: 1) }
        }
        .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 4)
    }

    private func arrow(_ glyph: String, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(.spaceMono(18))
                .foregroundStyle(enabled ? Color.inkSecondary : ghost)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).disabled(!enabled)
        .accessibilityLabel(glyph == "‹" ? "Previous month" : "Next month")
        .accessibilityIdentifier(id)
    }

    // MARK: Grid

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            Text("WK").font(.spaceMono(7)).tracking(1.5).foregroundStyle(ghost).frame(width: 30)
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                Text(d).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
    }

    private func grid(_ l: OreCalendarLogic) -> some View {
        VStack(spacing: 6) {
            ForEach(l.rows(for: month, selection: selection), id: \.monday) { row in
                HStack(spacing: 6) {
                    weekCell(row)
                    ForEach(Array(row.tiles.enumerated()), id: \.offset) { _, t in dayCell(t, l) }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
    }

    private func weekCell(_ row: CalendarWeekRow) -> some View {
        Button {
            guard row.selectable else { return }
            let sel = CalendarSelection.week(row.monday)
            selection = sel; onSelect(sel)
        } label: {
            Text("\(row.number)")
                .font(.spaceMono(9, weight: .bold)).tracking(0.5)
                .foregroundStyle(row.selected ? Color.accentInk : row.selectable ? Color.inkMuted : ghost)
                .frame(width: 30, height: 50)
                .background(row.selected ? tint : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: row.selected ? 6 : 0))
                .overlay(alignment: .trailing) { Rectangle().fill(Color.dsHairLine).frame(width: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week \(row.number)")
        .accessibilityIdentifier(AX.calendar.week(row.number))
    }

    @ViewBuilder
    private func dayCell(_ t: CalendarTile, _ l: OreCalendarLogic) -> some View {
        if let date = t.date {
            let c = colors(t.state)
            Button {
                guard t.selectable else { return }
                let sel = CalendarSelection.day(date)
                selection = sel; onSelect(sel)
            } label: {
                VStack(spacing: 4) {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.spaceMono(13, weight: c.bold ? .bold : .regular)).foregroundStyle(c.fg)
                    Text(t.label).font(.spaceMono(6, weight: .bold)).tracking(0.5).foregroundStyle(c.label)
                        .lineLimit(1).fixedSize()
                }
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(c.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(c.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(Calendar.current.component(.day, from: date)) \(t.label)")
            .accessibilityIdentifier(AX.calendar.day(WorkoutCalendarData.key(date, .current)))
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: 50)
        }
    }

    private func colors(_ s: CalendarTile.State) -> (bg: Color, border: Color, fg: Color, label: Color, bold: Bool) {
        switch s {
        case .selected: return (Color.oreAccent, .clear, .white, .white.opacity(0.9), true)
        case .trained: return (tint, Color.oreAccent.opacity(0.45), Color.accentInk, Color.accentInk, true)
        case .today: return (.clear, Color.inkSecondary, Color.inkPrimary, Color.inkSecondary, true)
        case .planned, .rest, .other, .blank: return (.clear, Color.dsHairLine, Color.inkMuted, Color.inkMuted, false)
        }
    }

    // MARK: Card area

    @ViewBuilder
    private func cardArea(_ l: OreCalendarLogic) -> some View {
        let cards: [CalendarCard] = {
            switch selection {
            case .none: return []
            case .day(let d): return [l.card(for: d)]
            case .week(let w): return cardAction == .openWorkout ? l.cards(forWeek: w) : [l.weekCard(forWeek: w)]
            }
        }()
        VStack(spacing: 8) {
            ForEach(Array(cards.enumerated()), id: \.offset) { _, card in cardView(card) }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, mode == .modal ? 16 : 24)
    }

    private func cardView(_ card: CalendarCard) -> some View {
        let tappable: Bool = cardAction == .openWorkout ? card.session != nil : (card.hasSessions && showOnMapAllowed)
        return Button {
            switch cardAction {
            case .openWorkout: if let s = card.session { onOpenWorkout(s) }
            case .showOnMap: onShowOnMap(selection)
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.date).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    Text(card.name).font(.archivo(22, weight: .black)).tracking(0.3)
                        .foregroundStyle(card.hasSessions ? Color.inkPrimary : Color.inkMuted)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    if !card.meta.isEmpty { Text(card.meta).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if cardAction == .showOnMap, card.hasSessions {
                    Text("SHOW ON MAP ›").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkPrimary)
                        .accessibilityIdentifier(AX.calendar.showOnMap)
                } else if cardAction == .openWorkout, card.showsChevron {
                    Text("›").font(.spaceMono(18)).foregroundStyle(ghost)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
        .accessibilityIdentifier(card.session != nil ? AX.calendar.cardOpen : AX.calendar.card)
    }

    private var showOnMapAllowed: Bool { true }
}
