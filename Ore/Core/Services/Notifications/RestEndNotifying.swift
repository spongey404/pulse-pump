import Foundation

/// Schedules/cancels the "rest is over" local notification so the alert still arrives when the
/// app is backgrounded or suspended. Abstracted so `RestTimerService` can be tested.
protocol RestEndNotifying {
    /// Fire a notification at `date`. `playSound` follows the rest-timer alert setting.
    func scheduleRestEnd(at date: Date, playSound: Bool)
    func cancelRestEnd()
}
