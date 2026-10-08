import Testing
import Foundation
import SwiftData
@testable import PulsePump

@MainActor
struct SplitScheduleTests {
    @Test func everyRealSplitHasAScheduleMatchingItsDaysPerWeek() {
        for type in SplitType.allCases where type != .none {
            let days = SplitSchedule.defaultDays(for: type)
            #expect(!days.isEmpty, "\(type) has no default days")
            if let perWeek = type.daysPerWeek { #expect(days.count == perWeek, "\(type)") }
            // Valid, unique weekdays, so reminders (one per weekday) never collide.
            #expect(days.allSatisfy { (1...7).contains($0.dayOfWeek) })
            #expect(Set(days.map(\.dayOfWeek)).count == days.count)
            #expect(days.allSatisfy { !$0.label.isEmpty && !$0.workoutType.isEmpty })
        }
        #expect(SplitSchedule.defaultDays(for: .none).isEmpty)
    }

    @Test func pplMapsToPushPullLegsTwice() {
        let days = SplitSchedule.defaultDays(for: .ppl)
        #expect(days.map(\.workoutType) == ["push", "pull", "legs", "push", "pull", "legs"])
        #expect(days.first?.dayOfWeek == 2)            // Monday
    }

    @Test func labelsMatchSeededPresetTemplates() {
        let presetNames = Set(TemplateSeedService.allTemplates.map(\.name))
        for type in [SplitType.ppl, .upperLower, .fullBody] {
            for d in SplitSchedule.defaultDays(for: type) {
                #expect(presetNames.contains(d.label), "\(d.label) is not a preset template")
            }
        }
    }

    @Test func applyCreatesThenUpdatesInPlace() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let user = User(name: "T")
        ctx.insert(user)
        let first = try #require(SplitSchedule.apply(type: .upperLower, to: user, modelContext: ctx))
        #expect(user.selectedSplit?.days.count == 4)
        let second = try #require(SplitSchedule.apply(type: .fullBody, to: user, modelContext: ctx))
        #expect(first.id == second.id)                                // no orphaned split rows
        #expect(try ctx.fetchCount(FetchDescriptor<Split>()) == 1)
        #expect(user.selectedSplit?.type == .fullBody && user.selectedSplit?.days.count == 3)
        #expect(SplitSchedule.apply(type: .none, to: user, modelContext: ctx) == nil)
        #expect(user.selectedSplit == nil)
    }

    @Test func repairFillsEmptySplitsOnceAndLeavesOthersAlone() throws {
        let ctx = ModelContext(try WidgetFixedDataTests.container())
        let empty = Split(type: .ppl)                                  // pre-fix onboarding: no days
        let custom = Split(type: .upperLower, days: [SplitDay(dayOfWeek: 4, label: "Mine", workoutType: "x")])
        let none = Split(type: .none)
        for s in [empty, custom, none] { ctx.insert(s) }

        #expect(SplitSchedule.repairMissingDays(modelContext: ctx) == 1)
        #expect(empty.days.count == 6)
        #expect(custom.days.map(\.label) == ["Mine"])
        #expect(none.days.isEmpty)
        #expect(SplitSchedule.repairMissingDays(modelContext: ctx) == 0)   // idempotent
    }

    // MARK: Notifications

    @Test func restDayAlertsNeverCoverTrainingDays() {
        let ppl = SplitSchedule.makeSplit(type: .ppl)                  // Mon-Sat
        #expect(NotificationService.restWeekdays(for: ppl) == [1])      // Sunday only
        let training = NotificationService.trainingWeekdays(for: ppl)
        #expect(Set(NotificationService.restWeekdays(for: ppl)).isDisjoint(with: training))

        let ul = SplitSchedule.makeSplit(type: .upperLower)            // Mon Tue Thu Fri
        #expect(NotificationService.restWeekdays(for: ul) == [1, 4, 7])
    }

    @Test func noScheduleMeansNoRestDayAlerts() {
        // Previously an empty split made all seven days "rest days", firing on training days too.
        #expect(NotificationService.restWeekdays(for: nil).isEmpty)
        #expect(NotificationService.restWeekdays(for: Split(type: .ppl)).isEmpty)
    }
}
