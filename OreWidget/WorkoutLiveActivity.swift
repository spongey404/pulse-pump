import ActivityKit
import WidgetKit
import SwiftUI

// WorkoutActivityAttributes lives in OreShared/WorkoutActivityAttributes.swift;
// layouts live in OreShared/Widgets/LiveActivityViews.swift.

struct WorkoutLiveActivity: Widget {
    private func preview(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> WorkoutLiveActivityPreviewState {
        WorkoutLiveActivityPreviewState(attributes: context.attributes, state: context.state, isStale: context.isStale)
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenCard(s: preview(context))
                .activityBackgroundTint(OreTheme.canvas)
                .activitySystemActionForegroundColor(OreTheme.ink)
        } dynamicIsland: { context in
            let s = preview(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { WorkoutIslandView.Leading(s: s).padding(.leading, 4) }
                DynamicIslandExpandedRegion(.trailing) { WorkoutIslandView.Trailing(s: s).padding(.trailing, 4) }
                DynamicIslandExpandedRegion(.bottom) { WorkoutIslandView.Bottom(s: s).padding(.horizontal, 4) }
            } compactLeading: {
                WorkoutIslandView.CompactLeading(s: s)
            } compactTrailing: {
                WorkoutIslandView.CompactTrailing(s: s)
            } minimal: {
                WorkoutIslandView.Minimal(s: s)
            }
            .keylineTint(Color(pwHex: "1AA7FF"))
        }
    }
}
