import Foundation
import UserNotifications
import SwiftData

/// Manages local push notifications for workout reminders and rest day alerts.
/// Social/challenge notifications require APNs + backend — stored as preferences for future use.
struct NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Workout Reminders

    /// Schedules weekly workout reminders for each training day in the user's split.
    /// Cancels any previously scheduled reminders first.
    func scheduleWorkoutReminders(split: Split?, reminderHour: Int = 8, reminderMinute: Int = 0) async {
        // Always cancel existing ones first
        cancelWorkoutReminders()

        guard UserDefaults.standard.bool(forKey: "workoutReminders"),
              let split, !split.days.isEmpty else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let center = UNUserNotificationCenter.current()

        for day in split.days {
            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body = "\(day.label) — let's go."
            content.sound = .default

            var components = DateComponents()
            components.weekday = day.dayOfWeek  // 1=Sun, 2=Mon, ..., 7=Sat
            components.hour = reminderHour
            components.minute = reminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = notificationId(prefix: "workout", dayOfWeek: day.dayOfWeek)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    func cancelWorkoutReminders() {
        let ids = (1...7).map { notificationId(prefix: "workout", dayOfWeek: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Rest Day Alerts

    /// Schedules weekly rest day nudges on days NOT covered by the user's split.
    func scheduleRestDayAlerts(split: Split?, reminderHour: Int = 10, reminderMinute: Int = 0) async {
        cancelRestDayAlerts()

        guard UserDefaults.standard.bool(forKey: "restDayAlerts") else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let trainingDays = Set(split?.days.map(\.dayOfWeek) ?? [])
        let restDays = Set(1...7).subtracting(trainingDays)

        guard !restDays.isEmpty else { return }

        let center = UNUserNotificationCenter.current()

        let messages = [
            "Rest day — recovery is where gains are made.",
            "Rest day — sleep well, eat well.",
            "Rest day — your muscles are growing.",
            "Active recovery day — a walk counts.",
        ]

        for (i, dayOfWeek) in restDays.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Rest day"
            content.body = messages[i % messages.count]
            content.sound = .default

            var components = DateComponents()
            components.weekday = dayOfWeek
            components.hour = reminderHour
            components.minute = reminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = notificationId(prefix: "rest", dayOfWeek: dayOfWeek)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    func cancelRestDayAlerts() {
        let ids = (1...7).map { notificationId(prefix: "rest", dayOfWeek: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Cancel All

    func cancelAll() {
        cancelWorkoutReminders()
        cancelRestDayAlerts()
    }

    // MARK: - Reschedule

    /// Call whenever the user's split or notification preferences change.
    func reschedule(split: Split?) async {
        await scheduleWorkoutReminders(split: split)
        await scheduleRestDayAlerts(split: split)
    }

    // MARK: - Helpers

    private func notificationId(prefix: String, dayOfWeek: Int) -> String {
        "com.pulse.PulsePump.\(prefix).weekday.\(dayOfWeek)"
    }
}
