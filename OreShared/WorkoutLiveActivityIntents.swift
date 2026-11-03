import Foundation
import AppIntents

extension Notification.Name {
    /// userInfo["delta"] = Int seconds
    static let oreLiveActivityAdjustRest = Notification.Name("pump.liveActivity.adjustRest")
    static let oreLiveActivitySkipRest = Notification.Name("pump.liveActivity.skipRest")
    static let oreLiveActivityLogSet = Notification.Name("pump.liveActivity.logSet")
}

/// LiveActivityIntents run in the app process, so perform() can reach the active WorkoutViewModel
/// through NotificationCenter.
struct AdjustRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Rest"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Seconds") var deltaSeconds: Int

    init() { deltaSeconds = 0 }
    init(deltaSeconds: Int) { self.deltaSeconds = deltaSeconds }

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .oreLiveActivityAdjustRest, object: nil,
                                        userInfo: ["delta": deltaSeconds])
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var isDiscoverable: Bool { false }

    init() {}

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .oreLiveActivitySkipRest, object: nil)
        return .result()
    }
}

struct LogSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Set"
    static var isDiscoverable: Bool { false }

    init() {}

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .oreLiveActivityLogSet, object: nil)
        return .result()
    }
}
