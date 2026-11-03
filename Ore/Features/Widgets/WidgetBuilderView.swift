import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Widget builder  (WidgetBuilderPhone.dc.html · builder screen)
// Pick a size, drag pieces onto the widget, tap a piece to choose what it shows.

private struct CanvasFramePreference: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct WidgetBuilderView: View {
    @Binding var library: [OreCustomWidget]
    let editingId: String?
    let snapshot: OreWidgetSnapshot
    let onClose: () -> Void

    @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<WorkoutTemplate> { $0.deletedAt == nil }, sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    @State private var draft: OreCustomWidget
    @State private var selected: String?
    @State private var drag: DragState?
    @State private var toast: String?
    @State private var info: OrePieceType?
    @State private var query = ""
    @State private var canvasFrame: CGRect = .zero
    @State private var seq = 1

    private struct DragState {
        var id: String
        var isNew: Bool
        var type: OrePieceType
        var metric: String
        var w: Int
        var h: Int
        var fx: Double
        var fy: Double
        var ox: Double
        var oy: Double
        var start: CGPoint
        var moved = false
        var inside = false
    }

    init(library: Binding<[OreCustomWidget]>, editingId: String?, snapshot: OreWidgetSnapshot, onClose: @escaping () -> Void) {
        _library = library
        self.editingId = editingId
        self.snapshot = snapshot
        self.onClose = onClose
        let existing = library.wrappedValue.first { $0.id == editingId }
        _draft = State(initialValue: existing ?? OreCustomWidget(
            id: "u\(Int(Date().timeIntervalSince1970))", name: "Custom \(library.wrappedValue.count + 1)",
            size: .small, pieces: [], edited: Date()))
    }

    private var grid: WidgetBuilderGrid { WidgetBuilderGrid(size: draft.size) }
    private var geo: OreGrid { OreGrid(size: draft.size) }
    private var zs: Double { draft.size == .lock ? 2 : 1 }
    private var stageBg: Color { draft.size == .lock ? Color(hex: "#3A424D") : Color.inkPrimary.opacity(0.06) }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                MoreScreenHeader(title: draft.name.uppercased(), onBack: onClose) {
                    Button { save() } label: {
                        Text("SAVE").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                            .padding(.horizontal, 12).frame(height: 30)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentInk.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                sizeChips
                stage
                panel
            }
            if let toast {
                Text(toast).font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.canvasBg)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.inkPrimary, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "builder")
        .background(Color.canvasBg.ignoresSafeArea())
        .onPreferenceChange(CanvasFramePreference.self) { canvasFrame = $0 }
    }

    // MARK: Size chips

    private var sizeChips: some View {
        HStack(spacing: 6) {
            ForEach(OreWidgetSize.allCases) { s in
                Button { setSize(s) } label: {
                    Text(s.label).font(.spaceMono(9, weight: .bold)).tracking(1)
                        .foregroundStyle(draft.size == s ? Color.canvasBg : Color.inkMuted)
                        .padding(.horizontal, 14).frame(height: 30)
                        .background(draft.size == s ? Color.inkPrimary : Color.clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(draft.size == s ? Color.clear : Color.dsHairLine, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: Stage

    private var placed: [OrePlacedPiece] {
        var out = draft.pieces.map { p -> OrePlacedPiece in
            var pp = OrePlacedPiece(p)
            if let d = drag, !d.isNew, d.moved, d.id == p.id { pp.x = d.fx; pp.y = d.fy; pp.dragging = true }
            return pp
        }
        if let d = drag, d.isNew, d.moved {
            var p = OrePlacedPiece(OreWidgetPiece(id: "new", type: d.type, metric: d.metric, x: 0, y: 0, w: d.w, h: d.h), dragging: true)
            p.x = d.fx; p.y = d.fy
            out.append(p)
        }
        return out
    }

    private var preview: (x: Int, y: Int, w: Int, h: Int)? {
        guard let d = drag, d.moved, d.inside,
              let s = grid.fit(draft.pieces, skipping: d.isNew ? nil : d.id, type: d.type, w: d.w, h: d.h, near: d.fx, d.fy)
        else { return nil }
        return (s.x, s.y, s.w, s.h)
    }

    private var stage: some View {
        let w = draft.size.width * zs, h = draft.size.height * zs
        let used = draft.pieces.reduce(0) { $0 + $1.w * $1.h }
        return ZStack {
            stageBg
                .contentShape(Rectangle())
                .onTapGesture { selected = nil; info = nil }
            ZStack(alignment: .topLeading) {
                OreWidgetCanvas(size: draft.size, pieces: placed, snapshot: snapshot, editing: true,
                                 selectedId: selected, preview: preview)
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)
                ForEach(draft.pieces) { p in
                    let r = geo.frame(x: Double(p.x), y: Double(p.y), w: p.w, h: p.h)
                    Color.clear.contentShape(Rectangle())
                        .frame(width: r.width * zs, height: r.height * zs)
                        .offset(x: r.minX * zs, y: r.minY * zs)
                        .gesture(pieceDrag(p))
                }
                if draft.pieces.isEmpty && drag?.moved != true {
                    Text("DRAG PIECES HERE").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .frame(width: w, height: h).allowsHitTesting(false)
                }
            }
            .frame(width: w, height: h)
            .background(GeometryReader { g in
                Color.clear.preference(key: CanvasFramePreference.self, value: g.frame(in: .named("builder")))
            })
            .padding(.bottom, 24)

            VStack {
                Spacer()
                HStack {
                    Text("\(used)/\(draft.size.cols * draft.size.rows) CELLS · \(draft.size == .lock ? "MONOCHROME · " : "")DRAG OUT TO REMOVE")
                        .font(.spaceMono(8)).tracking(1.2).foregroundStyle(draft.size == .lock ? Color.white.opacity(0.6) : Color.inkMuted)
                    Spacer()
                    HStack(spacing: 18) {
                        stageAction("TIDY") { tidy() }
                        stageAction("CLEAR") { selected = nil; draft.pieces = [] }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
            }
        }
        .frame(height: 390)
    }

    private func stageAction(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                .foregroundStyle(draft.size == .lock ? Color.white : Color.inkPrimary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Bottom panel (tray / configure)

    private var selectedPiece: OreWidgetPiece? { draft.pieces.first { $0.id == selected } }

    private var panel: some View {
        ZStack(alignment: .top) {
            Color.canvasBg
            if let p = selectedPiece { configure(p) } else { tray }
            if let t = info {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.info.name).font(.archivo(13, weight: .semibold))
                        Text(t.info.desc).font(.archivo(12))
                    }
                    Spacer(minLength: 0)
                    Button { info = nil } label: { Text("✕").font(.spaceMono(12)) }.buttonStyle(.plain)
                }
                .foregroundStyle(Color.canvasBg)
                .padding(.vertical, 12).padding(.leading, 14).padding(.trailing, 10)
                .background(Color.inkPrimary, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16).padding(.top, 44)
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var tray: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PIECES").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                Spacer()
                Text("DRAG IN · TAP TO ADD").font(.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(OreWidgetCatalog.order) { t in trayItem(t) }
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
    }

    private func trayItem(_ t: OrePieceType) -> some View {
        let disabled = draft.size == .lock && t.info.noLock
        return HStack(spacing: 6) {
            Text(t.info.glyph).font(.spaceMono(8, weight: .bold)).foregroundStyle(Color.inkPrimary)
                .frame(width: 26, height: 26).background(Color.surf2, in: RoundedRectangle(cornerRadius: 4))
            Text(t.info.name).font(.archivo(11, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                .lineLimit(2).minimumScaleFactor(0.8).frame(maxWidth: .infinity, alignment: .leading)
            Button { info = (info == t) ? nil : t } label: {
                Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(Color.inkMuted)
                    .frame(width: 28, height: 40)
            }
            .buttonStyle(.plain)
            .padding(.trailing, -4)
        }
        .padding(.horizontal, 6)
        .frame(height: 44)
        .background(Color.surf, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .opacity(disabled ? 0.35 : 1)
        .contentShape(Rectangle())
        .gesture(trayDrag(t))
    }

    // MARK: Configure selected piece

    private func configure(_ p: OreWidgetPiece) -> some View {
        let t = p.type.info
        let sizes = OreWidgetCatalog.sizes(for: p.type, in: draft.size)
        let options = metricOptions(for: p)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 2) {
                        Text(t.name).font(.archivo(18, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        Button { info = p.type } label: {
                            Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(Color.inkMuted).frame(width: 28, height: 28)
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    Button { selected = nil; query = "" } label: {
                        Text("DONE").font(.spaceMono(10, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)

                MoreSectionLabel(title: "SIZE", top: 6, bottom: 8)
                HStack(spacing: 6) {
                    ForEach(Array(sizes.enumerated()), id: \.offset) { _, s in
                        let on = s.0 == p.w && s.1 == p.h
                        Button { resizeSelected(w: s.0, h: s.1) } label: {
                            Text("\(s.0)×\(s.1)").font(.spaceMono(9, weight: .bold)).tracking(1)
                                .foregroundStyle(on ? Color.canvasBg : Color.inkMuted)
                                .padding(.horizontal, 14).frame(height: 30)
                                .background(on ? Color.inkPrimary : Color.clear, in: Capsule())
                                .overlay(Capsule().strokeBorder(on ? Color.clear : Color.dsHairLine, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                MoreSectionLabel(title: t.picker ? (p.type == .quick ? "TEMPLATE" : "EXERCISE") : "SHOWS", top: 14, bottom: 4)
                if t.picker && p.type == .pr {
                    TextField("Search exercises", text: $query)
                        .font(.archivo(14)).padding(.horizontal, 12).frame(height: 40)
                        .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ruleStrong, lineWidth: 1))
                        .padding(.horizontal, 16).padding(.vertical, 4)
                }
                ForEach(options, id: \.self) { name in
                    Button { setMetric(p.id, name) } label: {
                        HStack {
                            Text(label(for: name, type: p.type)).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                            Spacer()
                            Text(name == p.metric ? "✓" : "").font(.spaceMono(12, weight: .bold)).foregroundStyle(Color.accentInk)
                        }
                        .frame(height: 44)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                Button { removeSelected() } label: {
                    Text("Remove piece").font(.archivo(14, weight: .semibold)).foregroundStyle(Color.signalDown)
                        .frame(height: 44, alignment: .leading)
                }
                .buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 16)
            }
        }
    }

    /// Metric ids offered for a piece: catalog options, or the user's exercises / templates.
    private func metricOptions(for p: OreWidgetPiece) -> [String] {
        switch p.type {
        case .pr:
            let names = Array(Set(exercises.map(\.name) + OrePieceType.pr.info.metrics.map(\.id))).sorted()
            let filtered = query.isEmpty ? names : names.filter { $0.localizedCaseInsensitiveContains(query) }
            return filtered.sorted { ($0 == p.metric ? 0 : 1, $0) < ($1 == p.metric ? 0 : 1, $1) }.prefix(40).map { $0 }
        case .quick:
            let names = templates.map(\.name)
            return names.isEmpty ? p.type.info.metrics.map(\.id) : names
        default:
            return p.type.info.metrics.map(\.id)
        }
    }

    private func label(for id: String, type: OrePieceType) -> String {
        type.info.metrics.first { $0.id == id }?.label ?? id
    }

    // MARK: Gestures

    /// Canvas-local design coordinates for a point in the "builder" space.
    private func local(_ pt: CGPoint) -> (nx: Double, ny: Double) {
        ((pt.x - canvasFrame.minX) / zs, (pt.y - canvasFrame.minY) / zs)
    }

    private func updateDrag(_ d: inout DragState, at loc: CGPoint) {
        let l = local(loc)
        d.moved = d.moved || hypot(loc.x - d.start.x, loc.y - d.start.y) > 4
        let m = 24 * zs
        d.inside = canvasFrame.insetBy(dx: -m, dy: -m).contains(loc)
        d.fx = (l.nx - d.ox - draft.size.pad) / geo.uw
        d.fy = (l.ny - d.oy - draft.size.pad) / geo.uh
    }

    private func pieceDrag(_ p: OreWidgetPiece) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("builder"))
            .onChanged { v in
                if drag == nil {
                    let l = local(v.startLocation)
                    drag = DragState(id: p.id, isNew: false, type: p.type, metric: p.metric, w: p.w, h: p.h,
                                     fx: Double(p.x), fy: Double(p.y),
                                     ox: l.nx - (draft.size.pad + Double(p.x) * geo.uw),
                                     oy: l.ny - (draft.size.pad + Double(p.y) * geo.uh),
                                     start: v.startLocation, inside: true)
                }
                if var d = drag { updateDrag(&d, at: v.location); drag = d }
            }
            .onEnded { _ in finishDrag() }
    }

    private func trayDrag(_ t: OrePieceType) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("builder"))
            .onChanged { v in
                if drag == nil {
                    if draft.size == .lock && t.info.noLock { return }
                    guard let sz = OreWidgetCatalog.sizes(for: t, in: draft.size).first else { return }
                    let ox = Double(sz.0) * geo.uw / 2, oy = Double(sz.1) * geo.uh / 2
                    selected = nil
                    var d = DragState(id: "new", isNew: true, type: t, metric: defaultMetric(t), w: sz.0, h: sz.1,
                                      fx: 0, fy: 0, ox: ox, oy: oy, start: v.startLocation)
                    updateDrag(&d, at: v.startLocation)
                    d.moved = false
                    drag = d
                }
                if var d = drag { updateDrag(&d, at: v.location); drag = d }
            }
            .onEnded { v in
                if drag == nil, draft.size == .lock, t.info.noLock { flash("BODY MAP ISN’T AVAILABLE ON LOCK SCREEN") }
                finishDrag()
            }
    }

    private func defaultMetric(_ t: OrePieceType) -> String {
        switch t {
        case .quick: templates.first?.name ?? t.info.metrics[0].id
        case .pr: t.info.metrics[0].id
        default: t.info.metrics[0].id
        }
    }

    private func finishDrag() {
        guard let d = drag else { return }
        drag = nil
        if !d.moved {
            if d.isNew { addAuto(d.type) } else { selected = d.id }
            return
        }
        guard d.inside else {
            if !d.isNew {
                draft.pieces.removeAll { $0.id == d.id }
                selected = nil
                flash("PIECE REMOVED")
            }
            return
        }
        guard let s = grid.fit(draft.pieces, skipping: d.isNew ? nil : d.id, type: d.type, w: d.w, h: d.h, near: d.fx, d.fy) else {
            flash("NO ROOM · TIDY OR REMOVE A PIECE"); return
        }
        if d.isNew {
            draft.pieces.append(OreWidgetPiece(id: "n\(seq)", type: d.type, metric: d.metric, x: s.x, y: s.y, w: s.w, h: s.h))
            seq += 1
        } else if let i = draft.pieces.firstIndex(where: { $0.id == d.id }) {
            draft.pieces[i].x = s.x; draft.pieces[i].y = s.y; draft.pieces[i].w = s.w; draft.pieces[i].h = s.h
        }
    }

    // MARK: Actions

    private func flash(_ msg: String) {
        withAnimation { toast = msg }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation { if toast == msg { toast = nil } }
        }
    }

    private func addAuto(_ type: OrePieceType) {
        if draft.size == .lock && type.info.noLock { flash("BODY MAP ISN’T AVAILABLE ON LOCK SCREEN"); return }
        guard let sz = OreWidgetCatalog.sizes(for: type, in: draft.size).first,
              let s = grid.fit(draft.pieces, skipping: nil, type: type, w: sz.0, h: sz.1, near: nil, nil) else {
            flash("NO ROOM · TIDY OR REMOVE A PIECE"); return
        }
        draft.pieces.append(OreWidgetPiece(id: "n\(seq)", type: type, metric: defaultMetric(type), x: s.x, y: s.y, w: s.w, h: s.h))
        seq += 1
    }

    private func tidy() {
        let r = grid.tidy(draft.pieces)
        draft.pieces = r.out
        flash(r.dropped > 0 ? "\(r.dropped) PIECE\(r.dropped > 1 ? "S" : "") DIDN’T FIT" : "TIDIED")
    }

    private func setSize(_ s: OreWidgetSize) {
        guard s != draft.size else { return }
        let r = WidgetBuilderGrid(size: s).tidy(draft.pieces)
        selected = nil
        draft.size = s
        draft.pieces = r.out
        if r.dropped > 0 { flash("\(r.dropped) PIECE\(r.dropped > 1 ? "S" : "") DIDN’T FIT") }
    }

    private func resizeSelected(w: Int, h: Int) {
        guard let id = selected, let p = draft.pieces.first(where: { $0.id == id }) else { return }
        let o = grid.occupancy(draft.pieces, skipping: id)
        guard let b = grid.best(o, w: w, h: h, near: Double(p.x), Double(p.y)),
              let i = draft.pieces.firstIndex(where: { $0.id == id }) else { flash("NO ROOM AT THAT SIZE"); return }
        draft.pieces[i].x = b.x; draft.pieces[i].y = b.y; draft.pieces[i].w = b.w; draft.pieces[i].h = b.h
    }

    private func setMetric(_ id: String, _ metric: String) {
        if let i = draft.pieces.firstIndex(where: { $0.id == id }) { draft.pieces[i].metric = metric }
    }

    private func removeSelected() {
        guard let id = selected else { return }
        selected = nil
        draft.pieces.removeAll { $0.id == id }
    }

    private func save() {
        guard !draft.pieces.isEmpty else { flash("ADD A PIECE FIRST"); return }
        draft.edited = Date()
        if let i = library.firstIndex(where: { $0.id == draft.id }) { library[i] = draft } else { library.append(draft) }
        OreWidgetStore.saveLibrary(library)
        WidgetCenter.shared.reloadAllTimelines()
        onClose()
    }
}
