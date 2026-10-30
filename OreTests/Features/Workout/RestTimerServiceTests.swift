import Testing
import Foundation
import SwiftData
@testable import Ore

/// Records scheduling instead of touching UNUserNotificationCenter.
final class FakeRestNotifier: RestEndNotifying {
    private(set) var scheduled: [(date: Date, sound: Bool)] = []
    private(set) var cancelCount = 0
    func scheduleRestEnd(at date: Date, playSound: Bool) { scheduled.append((date, playSound)) }
    func cancelRestEnd() { cancelCount += 1 }
}

struct RestTimerServiceTests {

    @Test @MainActor func defaultDurations() {
        #expect(RestTimerService.defaultCompoundSeconds == 180)
        #expect(RestTimerService.defaultIsolationSeconds == 90)
    }

    @Test @MainActor func restDurationForCompound() {
        let service = RestTimerService()
        #expect(service.restDuration(isCompound: true) == 180)
        #expect(service.restDuration(isCompound: false) == 90)
    }

    @Test @MainActor func formattedTimeZero() {
        let service = RestTimerService()
        service.remainingSeconds = 0
        #expect(service.formattedTime == "0:00")
    }

    @Test @MainActor func formattedTimeWithMinutesAndSeconds() {
        let service = RestTimerService()
        service.remainingSeconds = 125 // 2:05
        #expect(service.formattedTime == "2:05")
    }

    @Test @MainActor func formattedTimeSingleDigitSeconds() {
        let service = RestTimerService()
        service.remainingSeconds = 63 // 1:03
        #expect(service.formattedTime == "1:03")
    }

    @Test @MainActor func progressWhenNotStarted() {
        let service = RestTimerService()
        #expect(service.progress == 0)
    }

    @Test @MainActor func progressCalculation() {
        let service = RestTimerService()
        service.totalSeconds = 100
        service.remainingSeconds = 25
        // progress = 1 - 25/100 = 0.75
        #expect(service.progress == 0.75)
    }

    @Test @MainActor func progressFullyComplete() {
        let service = RestTimerService()
        service.totalSeconds = 60
        service.remainingSeconds = 0
        #expect(service.progress == 1.0)
    }

    @Test @MainActor func stopResetsState() {
        let service = RestTimerService()
        service.totalSeconds = 60
        service.remainingSeconds = 30
        service.isRunning = true
        service.stop()
        #expect(!service.isRunning)
        #expect(service.remainingSeconds == 0)
    }

    // MARK: End-date based countdown

    @Test @MainActor func countdownIsDerivedFromTheEndDate() {
        let notifier = FakeRestNotifier()
        let service = RestTimerService(notifier: notifier)
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        service.start(seconds: 90, now: t0)
        #expect(service.isRunning && service.totalSeconds == 90 && service.remainingSeconds == 90)
        #expect(service.endDate == t0.addingTimeInterval(90))

        // The app was suspended for 40 s (no ticks): one refresh catches up exactly.
        service.refresh(now: t0.addingTimeInterval(40))
        #expect(service.remainingSeconds == 50)
        service.refresh(now: t0.addingTimeInterval(40.2))
        #expect(service.remainingSeconds == 50)             // rounds up, never skips ahead
        service.stop()
    }

    @Test @MainActor func finishingAfterBackgroundCompletesWithoutRingingAgain() {
        let service = RestTimerService(notifier: FakeRestNotifier())
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        service.start(seconds: 60, now: t0)
        service.refresh(now: t0.addingTimeInterval(300))     // back from a long background
        #expect(!service.isRunning && service.remainingSeconds == 0)
        #expect(service.completedAt == t0.addingTimeInterval(60))
    }

    @Test @MainActor func adjustMovesTheEndDateAndReschedulesTheNotification() {
        let notifier = FakeRestNotifier()
        let service = RestTimerService(notifier: notifier)
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        service.start(seconds: 60, now: t0)
        service.adjust(by: 15, now: t0.addingTimeInterval(10))
        #expect(service.endDate == t0.addingTimeInterval(75))
        #expect(service.remainingSeconds == 65)
        #expect(service.totalSeconds == 65)
        #expect(notifier.scheduled.last?.date == t0.addingTimeInterval(75))
        service.adjust(by: -100, now: t0.addingTimeInterval(10))   // past zero -> finishes
        #expect(!service.isRunning)
    }

    @Test @MainActor func startSchedulesAnEndNotificationAndStopCancelsIt() {
        let notifier = FakeRestNotifier()
        let service = RestTimerService(notifier: notifier)
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        service.start(seconds: 120, now: t0)
        #expect(notifier.scheduled.count == 1)
        #expect(notifier.scheduled[0].date == t0.addingTimeInterval(120))
        let cancelsBeforeStop = notifier.cancelCount
        service.skip()
        #expect(notifier.cancelCount > cancelsBeforeStop)
        #expect(service.endDate == nil && !service.isRunning)
    }

    // MARK: Which rest length applies

    @Test @MainActor func isolationVsCompoundUseTheirOwnGlobalSetting() {
        let service = WorkoutDraftTests.isolatedRestTimer(notifier: FakeRestNotifier())
        #expect(service.restDuration(isCompound: true) == 180)
        #expect(service.restDuration(isCompound: false) == 90)
    }

    @Test @MainActor func templateRestBeatsGlobalButUserOverrideBeatsTemplate() {
        let service = WorkoutDraftTests.isolatedRestTimer(notifier: FakeRestNotifier())
        let id = UUID()
        #expect(service.restDuration(isCompound: true, exerciseId: id, templateSeconds: 45) == 45)
        #expect(service.restDuration(isCompound: false, exerciseId: id, templateSeconds: 45) == 45)
        #expect(service.restDuration(isCompound: true, exerciseId: id) == 180)
        service.defaults.set(200, forKey: "restOverride_\(id.uuidString)")
        #expect(service.restDuration(isCompound: true, exerciseId: id, templateSeconds: 45) == 200)
    }

    @Test @MainActor func loggingASetUsesTheEntrysCompoundFlagAndTemplateRest() throws {
        let f = try WorkoutDraftTests.fixture()
        let notifier = FakeRestNotifier()
        let vm = WorkoutViewModel(restTimer: WorkoutDraftTests.isolatedRestTimer(notifier: notifier))
        vm.restTimer.mode = .autoStart
        let curl = Exercise(name: "Cable Curl", primaryMuscleGroups: [.biceps], equipmentType: .cable, movementPattern: .isolation)
        f.ctx.insert(curl)
        vm.startWorkout(modelContext: f.ctx, user: f.user)
        vm.addExercise(curl)
        vm.exerciseEntries[0].sets[0].weight = "20"; vm.exerciseEntries[0].sets[0].reps = "12"
        vm.logSet(exerciseIndex: 0, setIndex: 0, modelContext: f.ctx)
        #expect(!vm.exerciseEntries[0].isCompound)
        #expect(vm.restTimer.totalSeconds == RestTimerService.defaultIsolationSeconds)

        vm.exerciseEntries[0].restSeconds = 30                       // from the template
        vm.addSet(to: 0)
        vm.exerciseEntries[0].sets[1].weight = "20"; vm.exerciseEntries[0].sets[1].reps = "12"
        vm.logSet(exerciseIndex: 0, setIndex: 1, modelContext: f.ctx)
        #expect(vm.restTimer.totalSeconds == 30)
        vm.restTimer.stop()
        vm.stopDurationTimer()
    }
}
