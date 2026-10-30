#if DEBUG
import SwiftUI

/// `-debugSupernova paywall` opens the paywall straight away, for screenshots and visual comparison with the design.
struct SupernovaDebugScreen: View {
    let screen: String
    var body: some View {
        if screen == "starfield" {
            StarFieldDevPanel()
        } else {
            SupernovaPaywallView(onSubscribed: {}, onTrainFree: {})
        }
    }
}
#endif
