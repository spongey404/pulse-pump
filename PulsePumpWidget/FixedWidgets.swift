import WidgetKit
import SwiftUI
import AppIntents

// MARK: - The fixed widget set (Pump Widgets.dc.html)
// Every widget's layout lives in PumpShared/Widgets (also drawn by the in-app Widget Gallery).
// This file is only WidgetKit plumbing: intents (layout A/B, body-map metric), providers, hosts.

enum PWVariantOption: String, AppEnum {
    case a, b
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
    static var caseDisplayRepresentations: [PWVariantOption: DisplayRepresentation] = [
        .a: "A · Primary", .b: "B · Alternate",
    ]
    var variant: PWVariant { self == .a ? .a : .b }
}

enum PWMetricOption: String, AppEnum {
    case volume, recency
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Shows"
    static var caseDisplayRepresentations: [PWMetricOption: DisplayRepresentation] = [
        .volume: "Volume · 7 days", .recency: "Recency · days since trained",
    ]
    var metric: PWBodyMetric { self == .volume ? .volume : .recency }
}

struct PWVariantIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Layout"
    static var description = IntentDescription("Choose the widget layout.")
    @Parameter(title: "Layout", default: .a) var layout: PWVariantOption
}

struct PWBodyMapIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Body map"
    static var description = IntentDescription("Choose the layout and what the heat map shows.")
    @Parameter(title: "Layout", default: .a) var layout: PWVariantOption
    @Parameter(title: "Shows", default: .volume) var shows: PWMetricOption
}

struct PWEntry: TimelineEntry {
    let date: Date
    let snap: PumpWidgetSnapshot
    var variant: PWVariant = .a
    var metric: PWBodyMetric = .volume
}

/// Real data when the user has workouts; otherwise a real *empty* snapshot (placeholder state),
/// never the design's sample with Plus unlocked. The sample is only for previews (gallery).
private func currentSnapshot(isPreview: Bool = false) -> PumpWidgetSnapshot {
    if isPreview { return .sample }
    return PumpWidgetSnapshot.resolved(stored: PumpWidgetStore.loadSnapshot())
}
private var nextRefresh: Date { Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date() }

struct PWVariantProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PWEntry { PWEntry(date: Date(), snap: .sample) }
    func snapshot(for c: PWVariantIntent, in context: Context) async -> PWEntry {
        PWEntry(date: Date(), snap: currentSnapshot(isPreview: context.isPreview), variant: c.layout.variant)
    }
    func timeline(for c: PWVariantIntent, in context: Context) async -> Timeline<PWEntry> {
        Timeline(entries: [PWEntry(date: Date(), snap: currentSnapshot(), variant: c.layout.variant)], policy: .after(nextRefresh))
    }
}

struct PWBodyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PWEntry { PWEntry(date: Date(), snap: .sample) }
    func snapshot(for c: PWBodyMapIntent, in context: Context) async -> PWEntry {
        PWEntry(date: Date(), snap: currentSnapshot(isPreview: context.isPreview), variant: c.layout.variant, metric: c.shows.metric)
    }
    func timeline(for c: PWBodyMapIntent, in context: Context) async -> Timeline<PWEntry> {
        Timeline(entries: [PWEntry(date: Date(), snap: currentSnapshot(), variant: c.layout.variant, metric: c.shows.metric)], policy: .after(nextRefresh))
    }
}

// MARK: Host — scales the design-size layout to the real widget container

struct PWHost<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    @ViewBuilder var content: (PWFamily) -> Content

    private var pw: PWFamily {
        switch family {
        case .systemMedium: .medium
        case .systemLarge, .systemExtraLarge: .large
        default: .small
        }
    }

    var body: some View {
        let design = pw.size
        GeometryReader { geo in
            let s = min(geo.size.width / design.width, geo.size.height / design.height)
            content(pw)
                .frame(width: design.width, height: design.height, alignment: .topLeading)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }
}

// MARK: Descriptors

protocol PWWidgetDescriptor {
    static var kind: String { get }
    static var displayName: String { get }
    static var blurb: String { get }
    static var families: [WidgetFamily] { get }
    @MainActor static func view(_ family: WidgetFamily, _ e: PWEntry) -> AnyView
}

/// Reads the widget family from the environment and hands it to the descriptor.
struct PWWidgetView<D: PWWidgetDescriptor>: View {
    @Environment(\.widgetFamily) private var family
    let entry: PWEntry
    var body: some View { D.view(family, entry) }
}

struct PWWidget<D: PWWidgetDescriptor>: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: D.kind, intent: PWVariantIntent.self, provider: PWVariantProvider()) { e in
            PWWidgetView<D>(entry: e)
        }
        .configurationDisplayName(D.displayName)
        .description(D.blurb)
        .supportedFamilies(D.families)
        .contentMarginsDisabled()
    }
}

struct PWBodyMapWidgetDef: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PumpBodyMap", intent: PWBodyMapIntent.self, provider: PWBodyProvider()) { e in
            PWBodyMapView(entry: e)
        }
        .configurationDisplayName("Body map")
        .description(BodyMapWidget.blurb)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct PWBodyMapView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PWEntry
    var body: some View {
        homeContent(family, entry) { fam in
            PWPlusGate(family: fam, snap: entry.snap, locked: .bodyMap) {
                BodyMapWidget(family: fam, variant: entry.variant, snap: entry.snap, metric: entry.metric)
            }
        }
    }
}

// MARK: Helpers

/// Home-screen content scaled from design size, on the canvas container background.
@MainActor
func homeContent<V: View>(_ family: WidgetFamily, _ e: PWEntry, @ViewBuilder _ v: @escaping (PWFamily) -> V) -> some View {
    PWHost { v($0) }
        .containerBackground(for: .widget) {
            PumpTheme.canvas
        }
}

private func home<V: View>(_ f: WidgetFamily, _ e: PWEntry, @ViewBuilder _ v: @escaping (PWFamily) -> V) -> AnyView {
    AnyView(homeContent(f, e, v))
}

private func lock<V: View>(@ViewBuilder _ v: () -> V) -> AnyView {
    AnyView(v().containerBackground(for: .widget) { Color.clear })
}

private func circular<V: View>(@ViewBuilder _ v: () -> V) -> AnyView {
    AnyView(ZStack { AccessoryWidgetBackground(); v() }.containerBackground(for: .widget) { Color.clear })
}

private let homeFamilies: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]

// MARK: 01 Next workout
enum NextWorkoutDesc: PWWidgetDescriptor {
    static let kind = "PumpNextWorkout"
    static let displayName = "Next workout"
    static let blurb = "The predicted session with confidence. A: START button. B: first lift."
    static let families: [WidgetFamily] = homeFamilies + [.accessoryRectangular, .accessoryInline]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        switch f {
        case .accessoryRectangular: lock { LockRectNext(snap: e.snap) }
        case .accessoryInline: lock { LockInlineNext(snap: e.snap) }
        default: home(f, e) { NextWorkoutWidget(family: $0, variant: e.variant, snap: e.snap) }
        }
    }
}

// MARK: 02 Streak
enum StreakDesc: PWWidgetDescriptor {
    static let kind = "PumpStreak"
    static let displayName = "Streak"
    static let blurb = StreakWidget.blurb
    static let families: [WidgetFamily] = homeFamilies + [.accessoryCircular]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        switch f {
        case .accessoryCircular: circular { LockCircularStreak(snap: e.snap, drawsDisc: false) }
        default: home(f, e) { StreakWidget(family: $0, variant: e.variant, snap: e.snap) }
        }
    }
}

// MARK: 03 Weekly volume
enum WeeklyVolumeDesc: PWWidgetDescriptor {
    static let kind = "PumpWeeklyVolume"
    static let displayName = "Weekly volume"
    static let blurb = WeeklyVolumeWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .accessoryRectangular]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        switch f {
        case .accessoryRectangular: lock { LockRectVolume(snap: e.snap) }
        default: home(f, e) { WeeklyVolumeWidget(family: $0, variant: e.variant, snap: e.snap) }
        }
    }
}

// MARK: 05 Muscle balance (Plus)
enum BalanceDesc: PWWidgetDescriptor {
    static let kind = "PumpBalance"
    static let displayName = "Muscle balance"
    static let blurb = BalanceWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { fam in
            PWPlusGate(family: fam, snap: e.snap, locked: .balance) { BalanceWidget(family: fam, variant: e.variant, snap: e.snap) }
        }
    }
}

// MARK: 06 PR watch (Plus)
enum PRWatchDesc: PWWidgetDescriptor {
    static let kind = "PumpPRWatch"
    static let displayName = "PR watch"
    static let blurb = PRWatchWidget.blurb
    static let families: [WidgetFamily] = homeFamilies + [.accessoryRectangular]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        switch f {
        case .accessoryRectangular: lock { LockRectPR(snap: e.snap) }
        default:
            home(f, e) { fam in
                PWPlusGate(family: fam, snap: e.snap, locked: .prWatch) { PRWatchWidget(family: fam, variant: e.variant, snap: e.snap) }
            }
        }
    }
}

// MARK: 07 Deload and recovery (Plus)
enum DeloadDesc: PWWidgetDescriptor {
    static let kind = "PumpDeload"
    static let displayName = "Deload and recovery"
    static let blurb = DeloadWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { fam in
            PWPlusGate(family: fam, snap: e.snap, locked: .deload) { DeloadWidget(family: fam, variant: e.variant, snap: e.snap) }
        }
    }
}

// MARK: 09 Last session recap
enum RecapDesc: PWWidgetDescriptor {
    static let kind = "PumpRecap"
    static let displayName = "Last session"
    static let blurb = RecapWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { RecapWidget(family: $0, variant: e.variant, snap: e.snap) }
    }
}

// MARK: 10 Program
enum ProgramDesc: PWWidgetDescriptor {
    static let kind = "PumpProgram"
    static let displayName = "Program"
    static let blurb = ProgramWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { ProgramWidget(family: $0, variant: e.variant, snap: e.snap) }
    }
}

// MARK: 11 Weekly goal
enum GoalDesc: PWWidgetDescriptor {
    static let kind = "PumpGoal"
    static let displayName = "Weekly goal"
    static let blurb = GoalWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall, .accessoryCircular]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        switch f {
        case .accessoryCircular: circular { LockCircularGoal(snap: e.snap, drawsDisc: false) }
        default: home(f, e) { GoalWidget(family: $0, variant: e.variant, snap: e.snap) }
        }
    }
}

// MARK: 12 Bodyweight
enum BodyweightDesc: PWWidgetDescriptor {
    static let kind = "PumpBodyweight"
    static let displayName = "Bodyweight"
    static let blurb = BodyweightWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { BodyweightWidget(family: $0, variant: e.variant, snap: e.snap) }
    }
}

// MARK: 13 Friends
enum FriendsDesc: PWWidgetDescriptor {
    static let kind = "PumpFriends"
    static let displayName = "Friends"
    static let blurb = FriendsWidget.blurb
    static let families: [WidgetFamily] = [.systemMedium]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { FriendsWidget(family: $0, variant: e.variant, snap: e.snap) }
    }
}

// MARK: 14 Quick start
enum QuickStartDesc: PWWidgetDescriptor {
    static let kind = "PumpQuickStart"
    static let displayName = "Quick start"
    static let blurb = QuickStartWidget.blurb
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { QuickStartWidget(family: $0, variant: e.variant, snap: e.snap) }
    }
}

// MARK: 15 Pulse
enum PulseEcoDesc: PWWidgetDescriptor {
    static let kind = "PumpPulse"
    static let displayName = "Pulse"
    static let blurb = PulseEcoWidget.blurb
    static let families: [WidgetFamily] = [.systemMedium]
    static func view(_ f: WidgetFamily, _ e: PWEntry) -> AnyView {
        home(f, e) { PulseEcoWidget(family: $0, variant: e.variant, snap: e.snap) }
    }
}
