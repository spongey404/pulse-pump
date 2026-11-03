import SwiftUI
import Testing
@testable import Ore

/// The TYPE column of a set row: picking a type must not change what the row looks like. This was a bug
/// (the tag came out narrower than the dashed "+" it replaced, so the column jumped).
struct SetTypeChipTests {

    @MainActor private func size(of type: SetType) -> CGSize {
        UIHostingController(rootView: SetTypeChipLabel(type: type))
            .sizeThatFits(in: CGSize(width: 200, height: 100))
    }

    @Test @MainActor func theDashedPlaceholderIsTheReferenceBox() {
        #expect(size(of: .standard) == CGSize(width: SetTypeChipLabel.minWidth, height: SetTypeChipLabel.height))
    }

    @Test @MainActor func everyTypeIsAsTallAsThePlaceholderAndNeverNarrowerOrWiderThanTheColumn() {
        let placeholder = size(of: .standard)
        for type in SetType.allCases {
            let s = size(of: type)
            #expect(s.height == placeholder.height, "\(type) is \(s.height)pt tall, the placeholder is \(placeholder.height)")
            #expect(s.width >= placeholder.width, "\(type) is narrower than the placeholder (\(s.width) < \(placeholder.width))")
            #expect(s.width <= SetTypeChipLabel.column, "\(type) overflows the TYPE column (\(s.width) > \(SetTypeChipLabel.column))")
        }
    }

    @Test @MainActor func theShortTagsKeepThePlaceholderWidthSoTheRowDoesNotShift() {
        for type in [SetType.warmup, .superset, .restPause, .leftRight] {
            #expect(size(of: type).width == SetTypeChipLabel.minWidth, "\(type) should fill the same box as the placeholder")
        }
    }

    @Test func theColumnFitsThePlaceholderWithRoomForTheLongestTag() {
        #expect(SetTypeChipLabel.minWidth <= SetTypeChipLabel.column)
        #expect(SetTypeChipLabel.height == 22)
    }
}
