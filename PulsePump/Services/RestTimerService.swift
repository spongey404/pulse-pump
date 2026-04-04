import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
class RestTimerService {
    var isRunning = false
    var remainingSeconds: Int = 0
    var totalSeconds: Int = 0

    var mode: RestTimerMode {
        get { RestTimerMode(rawValue: UserDefaults.standard.string(forKey: "restTimerMode") ?? "") ?? .autoStart }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "restTimerMode") }
    }

    var alertType: AlertType {
        get { AlertType(rawValue: UserDefaults.standard.string(forKey: "restTimerAlertType") ?? "") ?? .sound }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "restTimerAlertType") }
    }

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?

    static let defaultCompoundSeconds = 180
    static let defaultIsolationSeconds = 90

    func start(seconds: Int) {
        stop()
        totalSeconds = seconds
        remainingSeconds = seconds
        isRunning = true
        let timerInstance = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        timer = timerInstance
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
    }

    func dismiss() {
        stop()
    }

    func restDuration(isCompound: Bool) -> Int {
        isCompound ? Self.defaultCompoundSeconds : Self.defaultIsolationSeconds
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

    private func tick() {
        guard remainingSeconds > 0 else {
            timerCompleted()
            return
        }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            timerCompleted()
        }
    }

    private func timerCompleted() {
        stop()
        playAlert()
    }

    private func playAlert() {
        switch alertType {
        case .sound, .both:
            AudioServicesPlaySystemSound(1005)
        case .vibration:
            break
        case .silent:
            break
        }
    }
}
