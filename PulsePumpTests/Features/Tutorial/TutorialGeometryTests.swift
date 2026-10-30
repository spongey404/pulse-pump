import CoreGraphics
import Testing
@testable import PulsePump

/// What counts as a tap on a tutorial target. It must never be bigger than the control itself: a tap in
/// extra margin would move the tutorial on while the app ignored it (the Discard modal that never opened).
struct TutorialGeometryTests {

    @Test @MainActor func theTapAreaIsTheControlPlusAHair() {
        let back = CGRect(x: 14, y: 48, width: 28, height: 42)
        let hole = TutorialPresenter.hole(for: back)
        #expect(hole == CGRect(x: 14 - TutorialPresenter.holePadding, y: 48 - TutorialPresenter.holePadding,
                               width: 28 + 2 * TutorialPresenter.holePadding, height: 42 + 2 * TutorialPresenter.holePadding))
        #expect(TutorialPresenter.holePadding <= 4, "a few points at most")
    }

    @Test @MainActor func aSmallControlIsNotGrownForTapping() {
        let circle = CGRect(x: 350, y: 300, width: 22, height: 22)
        let hole = TutorialPresenter.hole(for: circle)
        #expect(hole.width < 44 && hole.height < 44, "taps only count on the real control")
    }

    @Test @MainActor func theLightForASmallControlTracesItsOutline() {
        let hole = TutorialPresenter.hole(for: CGRect(x: 350, y: 300, width: 22, height: 22))
        #expect(TutorialPresenter.lit(hole) == hole, "no oversized halo around a small button")
    }

    @Test @MainActor func growingTheLightKeepsItCentredOnTheControl() {
        let hole = TutorialPresenter.hole(for: CGRect(x: 100, y: 200, width: 20, height: 30))
        let lit = TutorialPresenter.lit(hole)
        #expect(abs(lit.midX - hole.midX) < 0.001 && abs(lit.midY - hole.midY) < 0.001)
    }

    @Test @MainActor func aBigControlIsLitExactlyAsBigAsItIs() {
        let hole = TutorialPresenter.hole(for: CGRect(x: 10, y: 700, width: 380, height: 54))
        #expect(TutorialPresenter.lit(hole) == hole)
    }
}
