import SwiftUI
import SwiftData

// MARK: - More › Widgets  (WidgetBuilderPhone.dc.html · library screen)

struct WidgetsView: View {
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var library: [PumpCustomWidget] = []
    @State private var snapshot = PumpWidgetSnapshot()
    @State private var builder: BuilderTarget?
    @State private var showGallery = false

    private struct BuilderTarget: Identifiable { let id: String?; var key: String { id ?? "new" } }

    var body: some View {
        Group {
            if let builder {
                WidgetBuilderView(library: $library, editingId: builder.id, snapshot: snapshot) {
                    self.builder = nil
                }
                .id(builder.key)
            } else {
                libraryView
            }
        }
        .onAppear {
            load()
            #if DEBUG
            // `-debugWidgetEdit <id>` opens the builder on a saved widget (e.g. glance, full, lockline).
            if builder == nil, let id = UserDefaults.standard.string(forKey: "debugWidgetEdit") { builder = BuilderTarget(id: id) }
            #endif
        }
    }

    private func load() {
        let stored = PumpWidgetStore.loadLibrary()
        library = stored.isEmpty ? PumpWidgetCatalog.presets() : stored
        if stored.isEmpty { PumpWidgetStore.saveLibrary(library) }
        let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isDraft }, sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        snapshot = WidgetDataService.buildSnapshot(workouts: workouts, modelContext: modelContext)
    }

    private var libraryView: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "WIDGETS", onBack: onBack) {
                Button { builder = BuilderTarget(id: nil) } label: {
                    Text("NEW").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                        .padding(.horizontal, 12).frame(height: 30)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentInk.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("Build a widget from only the pieces you want. On the home screen, add Pump Custom, then choose one of these in Edit Widget.")
                        .font(.archivo(13)).lineSpacing(3).foregroundStyle(Color.inkPrimary.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)

                    HStack {
                        Text("MY WIDGETS").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        Spacer()
                        Text("\(library.count)").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    }
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 6)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                    ForEach(library) { w in row(w) }

                    Button { builder = BuilderTarget(id: nil) } label: {
                        HStack(spacing: 6) {
                            Text("+").font(.spaceMono(14))
                            Text("NEW WIDGET").font(.spaceMono(10, weight: .bold)).tracking(1.5)
                        }
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    MoreSectionLabel(title: "PREVIEW")
                    MoreRow(icon: "square.grid.2x2", label: "Widget gallery", value: "ALL WIDGETS") { showGallery = true }
                    Spacer().frame(height: 32)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .fullScreenCover(isPresented: $showGallery) {
            WidgetGalleryView(onBack: { showGallery = false })
        }
    }

    private func row(_ w: PumpCustomWidget) -> some View {
        let scale: Double = switch w.size { case .small: 0.6; case .medium, .large: 0.3; case .lock: 0.65 }
        let tw = w.size.width * scale
        let days = Calendar.current.dateComponents([.day], from: w.edited, to: Date()).day ?? 0
        let age = days < 1 ? "TODAY" : days < 7 ? "\(days)D AGO" : "\(days / 7)W AGO"
        return Button { builder = BuilderTarget(id: w.id) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(w.size == .lock ? Color(hex: "#3A424D") : Color.inkPrimary.opacity(0.06))
                    PumpWidgetCanvas(size: w.size, pieces: w.pieces.map { PumpPlacedPiece($0) }, snapshot: snapshot)
                        .frame(width: tw)
                        .allowsHitTesting(false)
                }
                .frame(width: tw + 8, height: w.size.height * scale + 8)
                .frame(width: 112)
                VStack(alignment: .leading, spacing: 4) {
                    Text(w.name).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text("\(w.size.label) · \(w.pieces.count) PIECES · \(age)")
                        .font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                library.removeAll { $0.id == w.id }
                PumpWidgetStore.saveLibrary(library)
            }
        }
    }
}
