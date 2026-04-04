import SwiftUI
import WidgetKit

@main
struct PulsePumpWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulsePumpWidget()
        WorkoutLiveActivity()
    }
}
