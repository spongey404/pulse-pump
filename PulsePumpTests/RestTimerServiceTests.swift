import Testing
@testable import PulsePump

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
}
