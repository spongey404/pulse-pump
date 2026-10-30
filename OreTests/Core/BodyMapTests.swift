import SwiftUI
import Testing
@testable import Ore

/// The design's body map: the path reader, the muscle levels and the colour mix.
struct BodyMapTests {

    // MARK: SVG path reader

    @Test func readsMoveLineAndQuadraticCurves() {
        let p = SVGPathLite.path("M70 56 Q86 51 99 54 L99 92 Q84 96 69 91 Z")
        #expect(!p.isEmpty)
        let box = p.boundingRect
        #expect(box.minX >= 69 - 0.5 && box.maxX <= 99 + 0.5, "x runs 69…99")
        #expect(box.minY >= 51 - 0.5 && box.maxY <= 96 + 0.5)
    }

    @Test func aStraightPathHasTheExactBounds() {
        let box = SVGPathLite.path("M10 20 L30 20 L30 50 L10 50 Z").boundingRect
        #expect(box == CGRect(x: 10, y: 20, width: 20, height: 30))
    }

    @Test func negativeNumbersAndCommasAreRead() {
        let box = SVGPathLite.path("M-5,-5 L5,-5 L5,5 L-5,5 Z").boundingRect
        #expect(box == CGRect(x: -5, y: -5, width: 10, height: 10))
        #expect(SVGPathLite.path("M10-5 L20-5 L20 5 Z").boundingRect.minY == -5, "a minus sign starts a new number")
    }

    @Test func aCommandTheReaderDoesNotKnowDrawsNothingMore() {
        let p = SVGPathLite.path("M0 0 L10 10 C1 2 3 4 5 6 L99 99")
        #expect(p.boundingRect.maxX <= 10, "stops at the unsupported command instead of drawing garbage")
        #expect(SVGPathLite.path("").isEmpty)
    }

    // MARK: Body map shapes

    @Test func everyMuscleShapeIsReadableAndInsideTheFigureBox() {
        let box = MuscleLevelMapShapes.viewBox.insetBy(dx: -2, dy: -2)
        for (name, data) in MuscleLevelMapShapes.front + MuscleLevelMapShapes.back {
            let p = SVGPathLite.path(data)
            #expect(!p.isEmpty, "\(name) parses")
            #expect(box.contains(p.boundingRect), "\(name) sits inside the 160 × 292 figure")
        }
    }

    @Test func theMapHasEveryRegionTheDesignNames() {
        let expected: Set<String> = ["traps", "chest", "frontDelts", "sideDelts", "rearDelts", "biceps", "triceps", "forearms", "abs",
                                     "obliques", "upperBack", "lats", "lowerBack", "glutes", "quads", "hamstrings", "calves"]
        #expect(MuscleLevelMapShapes.muscles == expected)
    }

    @Test func leftAndRightMusclesAreBothDrawn() {
        let chest = MuscleLevelMapShapes.front.filter { $0.muscle == "chest" }
        #expect(chest.count == 2, "a left and a right pec")
    }

    // MARK: Levels

    @Test func primaryMusclesAreFullAndSecondaryHalf() {
        let l = MuscleLevels.levels(primary: [.chest], secondary: [.triceps, .frontDelts])
        #expect(l == ["chest": 1.0, "triceps": 0.5, "frontDelts": 0.5])
    }

    @Test func aMuscleBothPrimaryAndSecondaryIsFull() {
        #expect(MuscleLevels.levels(primary: [.lats], secondary: [.lats])["lats"] == 1.0)
    }

    @Test func broadGroupsLightEveryRegionTheyCover() {
        let shoulders = MuscleLevels.levels(primary: [.shoulders], secondary: [])
        #expect(Set(shoulders.keys) == ["frontDelts", "sideDelts", "rearDelts"])
        let back = MuscleLevels.levels(primary: [.back], secondary: [])
        #expect(Set(back.keys) == ["upperBack", "lats", "lowerBack"])
    }

    @Test func groupsTheMapDoesNotDrawAreLeftOut() {
        #expect(MuscleLevels.levels(primary: [.neck, .hipFlexors, .adductors, .abductors], secondary: []).isEmpty)
    }

    @Test func everyRegionAMuscleGroupNamesExistsOnTheMap() {
        for group in MuscleGroup.allCases {
            for region in group.mapRegions { #expect(MuscleLevelMapShapes.muscles.contains(region), "\(group) → \(region)") }
        }
    }

    // MARK: Colour mix

    @Test func theMixIsTheBaseAtZeroTheAccentAtOneAndHalfwayBetween() {
        let accent = MuscleLevelMap.RGBA(r: 0.1, g: 0.65, b: 1, a: 1)
        let base = MuscleLevelMap.RGBA(r: 0.08, g: 0.1, b: 0.13, a: 0.035)
        #expect(MuscleLevelMap.mix(accent: accent, base: base, level: 0) == base)
        #expect(MuscleLevelMap.mix(accent: accent, base: base, level: 1) == accent)
        let half = MuscleLevelMap.mix(accent: accent, base: base, level: 0.5)
        #expect(abs(half.g - 0.375) < 0.0001 && abs(half.a - 0.5175) < 0.0001)
    }

    @Test func theLevelIsClampedToZeroAndOne() {
        let accent = MuscleLevelMap.RGBA(r: 1, g: 1, b: 1, a: 1), base = MuscleLevelMap.RGBA(r: 0, g: 0, b: 0, a: 0)
        #expect(MuscleLevelMap.mix(accent: accent, base: base, level: 3) == accent)
        #expect(MuscleLevelMap.mix(accent: accent, base: base, level: -1) == base)
    }
}
