import Foundation

enum RestTimerMode: String, Codable, CaseIterable, Identifiable {
    case autoStart
    case manual
    case autoStartWithDismiss

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .autoStart: "Auto-Start"
        case .manual: "Manual"
        case .autoStartWithDismiss: "Auto-Start with Dismiss"
        }
    }
}

enum AlertType: String, Codable, CaseIterable, Identifiable {
    case sound
    case vibration
    case both
    case silent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sound: "Sound"
        case .vibration: "Vibration"
        case .both: "Sound & Vibration"
        case .silent: "Silent (Visual Only)"
        }
    }
}
