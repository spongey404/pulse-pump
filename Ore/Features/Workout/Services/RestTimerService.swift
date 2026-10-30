import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
class RestTimerService {
    var isRunning = false
    var remainingSeconds: Int = 0
    var totalSeconds: Int = 0
    /// Set when a rest ran to zero (not when skipped/stopped); cleared by the next start/stop/logged set.
    var completedAt: Date?

    var mode: RestTimerMode {
        get { RestTimerMode(rawValue: defaults.string(forKey: "restTimerMode") ?? "") ?? .autoStart }
        set { defaults.set(newValue.rawValue, forKey: "restTimerMode") }
    }

    var alertType: AlertType {
        get { AlertType(rawValue: defaults.string(forKey: "restTimerAlertType") ?? "") ?? .sound }
        set { defaults.set(newValue.rawValue, forKey: "restTimerAlertType") }
    }

    /// When the running rest ends. The countdown is derived from this (not decremented per tick),
    /// so it stays correct across backgrounding, scrolling and dropped timer fires.
    private(set) var endDate: Date?

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private let notifier: RestEndNotifying
    let defaults: UserDefaults

    static let defaultCompoundSeconds = 180
    static let defaultIsolationSeconds = 90

    init(notifier: RestEndNotifying = SystemRestEndNotifier(), defaults: UserDefaults = .standard) {
        self.notifier = notifier
        self.defaults = defaults
    }

    func start(seconds: Int, now: Date = Date()) {
        stop()
        guard seconds > 0 else { return }
        totalSeconds = seconds
        remainingSeconds = seconds
        endDate = now.addingTimeInterval(TimeInterval(seconds))
        isRunning = true
        // `.common` mode keeps the display ticking while the user scrolls.
        let timerInstance = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(timerInstance, forMode: .common)
        timer = timerInstance
        if let endDate { notifier.scheduleRestEnd(at: endDate, playSound: alertType != .silent) }
    }

    func clearCompletion() { completedAt = nil }

    func stop() {
        completedAt = nil
        cancelTimer()
        notifier.cancelRestEnd()
        isRunning = false
        remainingSeconds = 0
        endDate = nil
    }

    /// Recomputes the countdown from the end date. Call when the app returns to the foreground;
    /// the repeating timer also calls it. Finishes the rest once the end date has passed.
    func refresh(now: Date = Date()) {
        guard isRunning, let endDate else { return }
        let remaining = Int((endDate.timeIntervalSince(now)).rounded(.up))
        if remaining <= 0 {
            // Only buzz if the rest ended just now; if we were suspended, the notification already did.
            timerCompleted(endedAt: endDate, alert: now.timeIntervalSince(endDate) < 2)
        } else if remaining != remainingSeconds {
            remainingSeconds = remaining
        }
    }

    /// Adds/removes seconds from the running rest (Live Activity -15S / +15S). Finishes the rest if it hits 0.
    func adjust(by delta: Int, now: Date = Date()) {
        guard isRunning, let current = endDate else { return }
        let newEnd = current.addingTimeInterval(TimeInterval(delta))
        if newEnd.timeIntervalSince(now) <= 0 {
            timerCompleted(endedAt: now, alert: true)
        } else {
            endDate = newEnd
            remainingSeconds = Int(newEnd.timeIntervalSince(now).rounded(.up))
            totalSeconds = max(totalSeconds, remainingSeconds)
            notifier.scheduleRestEnd(at: newEnd, playSound: alertType != .silent)
        }
    }

    /// Ends the rest immediately without an alert sound.
    func skip() { stop() }

    func dismiss() {
        stop()
    }

    /// Rest length for a just-logged set: the user's per-exercise override wins, then the
    /// template's `restSeconds`, then the global compound/isolation setting.
    func restDuration(isCompound: Bool, exerciseId: UUID? = nil, templateSeconds: Int? = nil) -> Int {
        if let exerciseId,
           let override = defaults.object(forKey: "restOverride_\(exerciseId.uuidString)") as? Int {
            return override
        }
        if let templateSeconds, templateSeconds > 0 { return templateSeconds }
        let compound = defaults.object(forKey: "compoundRestSeconds") as? Int ?? Self.defaultCompoundSeconds
        let isolation = defaults.object(forKey: "isolationRestSeconds") as? Int ?? Self.defaultIsolationSeconds
        return isCompound ? compound : isolation
    }

    static func setPerExerciseOverride(exerciseId: UUID, seconds: Int?) {
        if let seconds {
            UserDefaults.standard.set(seconds, forKey: "restOverride_\(exerciseId.uuidString)")
        } else {
            UserDefaults.standard.removeObject(forKey: "restOverride_\(exerciseId.uuidString)")
        }
    }

    static func perExerciseOverride(exerciseId: UUID) -> Int? {
        UserDefaults.standard.object(forKey: "restOverride_\(exerciseId.uuidString)") as? Int
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timerCompleted(endedAt: Date, alert: Bool) {
        stop()
        completedAt = endedAt
        if alert { playAlert() }
    }

    private func playAlert() {
        switch alertType {
        case .sound:
            AudioServicesPlaySystemSound(1005)
        case .vibration:
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        case .both:
            AudioServicesPlaySystemSound(1005)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        case .silent:
            break
        }
    }
}
