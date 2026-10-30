import Foundation
import UserNotifications

/// Real `RestEndNotifying`: one pending time-interval local notification, replaced on every start.
/// While the app is in the foreground iOS does not show it (no presentation delegate), so it only
/// ever surfaces when the app is backgrounded.
struct SystemRestEndNotifier: RestEndNotifying {
    static let identifier = "com.pulse.PulsePump.restTimerEnd"

    func scheduleRestEnd(at date: Date, playSound: Bool) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest done"
        content.body = "Log your next set"
        content.sound = playSound ? .default : nil
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.add(request)
    }

    func cancelRestEnd() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}
