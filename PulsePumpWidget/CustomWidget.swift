import WidgetKit
import SwiftUI
import AppIntents

// MARK: - "Pump Custom" — renders a widget built in More › Widgets
// (design: Widget Builder.dc.html). Saved widgets live in the App Group; the user picks one
// in Edit Widget.

struct CustomWidgetEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Custom widget"
    static var defaultQuery = CustomWidgetQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct CustomWidgetQuery: EntityQuery {
    private func all() -> [CustomWidgetEntity] {
        PumpWidgetStore.loadLibrary().map { CustomWidgetEntity(id: $0.id, name: $0.name) }
    }
    func entities(for identifiers: [String]) async throws -> [CustomWidgetEntity] {
        all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [CustomWidgetEntity] { all() }
    func defaultResult() async -> CustomWidgetEntity? { all().first }
}

struct SelectCustomWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Pump Custom"
    static var description = IntentDescription("Choose a widget you built in Pump.")

    @Parameter(title: "Widget")
    var widget: CustomWidgetEntity?
}

struct CustomWidgetEntry: TimelineEntry {
    let date: Date
    let widget: PumpCustomWidget?
    let snapshot: PumpWidgetSnapshot
}

struct CustomWidgetProvider: AppIntentTimelineProvider {
    private func entry(for config: SelectCustomWidgetIntent) -> CustomWidgetEntry {
        let lib = PumpWidgetStore.loadLibrary()
        let chosen = lib.first { $0.id == config.widget?.id } ?? lib.first
        return CustomWidgetEntry(date: Date(), widget: chosen, snapshot: PumpWidgetStore.loadSnapshot())
    }

    func placeholder(in context: Context) -> CustomWidgetEntry {
        CustomWidgetEntry(date: Date(), widget: PumpWidgetCatalog.presets().first, snapshot: PumpWidgetSnapshot())
    }
    func snapshot(for configuration: SelectCustomWidgetIntent, in context: Context) async -> CustomWidgetEntry {
        entry(for: configuration)
    }
    func timeline(for configuration: SelectCustomWidgetIntent, in context: Context) async -> Timeline<CustomWidgetEntry> {
        Timeline(entries: [entry(for: configuration)],
                 policy: .after(Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()))
    }
}

struct CustomWidgetView: View {
    let entry: CustomWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let w = entry.widget {
            PumpWidgetCanvas(size: w.size, pieces: w.pieces.map { PumpPlacedPiece($0) },
                             snapshot: entry.snapshot, drawsBackground: false, interactive: family != .systemSmall)
                .widgetURL(family == .systemSmall ? startURL(w) : nil)
        } else {
            VStack(spacing: 6) {
                Text("PUMP").font(.spaceMono(9, weight: .bold)).tracking(2)
                Text("Build a widget in More › Widgets")
                    .font(.spaceMono(8)).multilineTextAlignment(.center).foregroundStyle(PumpTheme.muted)
            }
        }
    }

    private func startURL(_ w: PumpCustomWidget) -> URL? {
        guard let p = w.pieces.first(where: { $0.type == .quick || ($0.type == .next && $0.metric == "start") }) else { return nil }
        return PumpWidgetSnapshot.startURL(template: p.type == .quick ? p.metric : nil)
    }
}

struct CustomWidget: Widget {
    let kind = "PumpCustomWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCustomWidgetIntent.self, provider: CustomWidgetProvider()) { entry in
            CustomWidgetView(entry: entry)
                .containerBackground(for: .widget) { PumpTheme.canvas }
        }
        .configurationDisplayName("Pump Custom")
        .description("A widget you built from only the pieces you want.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
