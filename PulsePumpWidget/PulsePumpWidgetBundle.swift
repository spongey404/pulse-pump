import SwiftUI
import WidgetKit

@main
struct PulsePumpWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulsePumpWidget()
        CustomWidget()
        PWWidget<NextWorkoutDesc>()
        PWWidget<StreakDesc>()
        PWWidget<WeeklyVolumeDesc>()
        PWBodyMapWidgetDef()
        PWWidget<BalanceDesc>()
        PWWidget<PRWatchDesc>()
        PWWidget<DeloadDesc>()
        PWWidget<RecapDesc>()
        PWWidget<ProgramDesc>()
        PWWidget<GoalDesc>()
        PWWidget<BodyweightDesc>()
        PWWidget<FriendsDesc>()
        PWWidget<QuickStartDesc>()
        PWWidget<PulseEcoDesc>()
        WorkoutLiveActivity()
    }
}
