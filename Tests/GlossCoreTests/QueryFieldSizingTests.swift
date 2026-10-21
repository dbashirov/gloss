import CoreGraphics
import Testing
@testable import GlossCore

private func height(dragging offset: CGFloat, resultRoom: CGFloat = 200) -> CGFloat {
    QueryFieldSizing.height(dragging: 80, by: offset, minHeight: 30, resultRoom: resultRoom)
}

struct QueryFieldSizingTests {
    @Test func followsTheDrag() {
        #expect(height(dragging: 40) == 120)
        #expect(height(dragging: -20) == 60)
    }

    @Test func keepsOneLineOfTheField() {
        #expect(height(dragging: -70) == 30)
    }

    @Test func leavesAStripOfTheResult() {
        // 200 of the result area minus the 48 it keeps
        #expect(height(dragging: 500) == 232)
    }

    @Test func neverGoesBelowMinimumWithoutRoom() {
        #expect(height(dragging: 20, resultRoom: 0) == 32)
        #expect(height(dragging: 20, resultRoom: -100) == 30)
    }
}
