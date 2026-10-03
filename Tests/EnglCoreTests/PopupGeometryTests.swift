import CoreGraphics
import Testing
@testable import EnglCore

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
// a second monitor to the right, lower than the main one
private let secondScreen = CGRect(x: 1440, y: -200, width: 1920, height: 1055)
private let size = CGSize(width: 380, height: 200)

private func origin(cursorX: CGFloat, cursorY: CGFloat, in frame: CGRect = screen) -> CGPoint {
    PopupGeometry.origin(
        cursor: CGPoint(x: cursorX, y: cursorY),
        size: size,
        visibleFrame: frame
    )
}

struct PopupGeometryTests {
    @Test func placesBelowRightOfCursorInScreenCenter() {
        #expect(origin(cursorX: 700, cursorY: 450) == CGPoint(x: 712, y: 238))
    }

    @Test func flipsLeftAtRightEdge() {
        #expect(origin(cursorX: 1400, cursorY: 450) == CGPoint(x: 1008, y: 238))
    }

    @Test func flipsUpAtBottomEdge() {
        #expect(origin(cursorX: 700, cursorY: 100) == CGPoint(x: 712, y: 112))
    }

    @Test func flipsBothWaysInBottomRightCorner() {
        #expect(origin(cursorX: 1430, cursorY: 10) == CGPoint(x: 1038, y: 22))
    }

    @Test func keepsInsideWhenCursorIsAboveVisibleFrame() {
        // a click on the menu bar icon: the cursor is above the visible frame
        #expect(origin(cursorX: 700, cursorY: 890) == CGPoint(x: 712, y: 675))
    }

    @Test func clampsWhenNoSideHasRoom() {
        let small = CGRect(x: 0, y: 0, width: 500, height: 300)

        let result = origin(cursorX: 250, cursorY: 150, in: small)

        #expect(result == CGPoint(x: 0, y: 100))
    }

    @Test func usesOffsetVisibleFrameOfSecondMonitor() {
        #expect(origin(cursorX: 2000, cursorY: 600, in: secondScreen) == CGPoint(x: 2012, y: 388))
        #expect(origin(cursorX: 3300, cursorY: 0, in: secondScreen) == CGPoint(x: 2908, y: 12))
        #expect(origin(cursorX: 3300, cursorY: -190, in: secondScreen) == CGPoint(x: 2908, y: -178))
    }

    @Test func panelLargerThanScreenKeepsTopLeftVisible() {
        let huge = CGSize(width: 2000, height: 1000)

        let popup = PopupGeometry.origin(
            cursor: CGPoint(x: 700, y: 450),
            size: huge,
            visibleFrame: screen
        )
        let pinned = PopupGeometry.clamp(
            origin: CGPoint(x: 1800, y: 30),
            size: huge,
            visibleFrame: secondScreen
        )

        #expect(popup == CGPoint(x: 0, y: -125))
        #expect(pinned == CGPoint(x: 1440, y: -145))
    }

    @Test func clampKeepsOriginThatFits() {
        let saved = CGPoint(x: 100, y: 100)

        #expect(PopupGeometry.clamp(origin: saved, size: size, visibleFrame: screen) == saved)
    }

    @Test(arguments: [
        (CGPoint(x: 5000, y: 3000), CGPoint(x: 1060, y: 675)),
        (CGPoint(x: -900, y: -700), CGPoint(x: 0, y: 0)),
        (CGPoint(x: 1300, y: 800), CGPoint(x: 1060, y: 675)),
    ])
    func clampsPinnedOriginOutsideScreens(saved: CGPoint, expected: CGPoint) {
        #expect(PopupGeometry.clamp(origin: saved, size: size, visibleFrame: screen) == expected)
    }

    @Test func pinnedOriginOfDisconnectedMonitorMovesToNearestScreen() throws {
        // the panel was pinned on a monitor left of the main one that is now gone
        let saved = CGPoint(x: -1500, y: 400)
        let frames = [screen, secondScreen]

        let index = try #require(PopupGeometry.nearestFrameIndex(to: saved, in: frames))
        let result = PopupGeometry.clamp(origin: saved, size: size, visibleFrame: frames[index])

        #expect(index == 0)
        #expect(result == CGPoint(x: 0, y: 400))
    }

    @Test func nearestFramePrefersContainingFrame() {
        let frames = [screen, secondScreen]

        #expect(PopupGeometry.nearestFrameIndex(to: CGPoint(x: 100, y: 100), in: frames) == 0)
        #expect(PopupGeometry.nearestFrameIndex(to: CGPoint(x: 2000, y: -100), in: frames) == 1)
        #expect(PopupGeometry.nearestFrameIndex(to: CGPoint(x: 4000, y: 0), in: frames) == 1)
        #expect(PopupGeometry.nearestFrameIndex(to: CGPoint(x: 0, y: 0), in: []) == nil)
    }

    @Test func resizeKeepsTopLeftCorner() {
        let frame = CGRect(x: 100, y: 400, width: 380, height: 200)

        let grown = PopupGeometry.resized(
            frame: frame,
            to: CGSize(width: 380, height: 300),
            visibleFrame: screen
        )
        let shrunk = PopupGeometry.resized(
            frame: frame,
            to: CGSize(width: 380, height: 100),
            visibleFrame: screen
        )

        #expect(grown == CGPoint(x: 100, y: 300))
        #expect(shrunk == CGPoint(x: 100, y: 500))
    }

    @Test func resizeNearBottomEdgeStaysOnScreen() {
        let frame = CGRect(x: 100, y: 20, width: 380, height: 200)

        let grown = PopupGeometry.resized(
            frame: frame,
            to: CGSize(width: 380, height: 480),
            visibleFrame: screen
        )

        #expect(grown == CGPoint(x: 100, y: 0))
    }

    @Test func pinnedTopLeftKeepsTopEdgeForAnyHeight() {
        let topLeft = PopupGeometry.topLeft(of: CGRect(x: 100, y: 200, width: 380, height: 480))

        let small = PopupGeometry.origin(
            topLeft: topLeft,
            size: CGSize(width: 380, height: 120),
            visibleFrame: screen
        )
        let large = PopupGeometry.origin(topLeft: topLeft, size: size, visibleFrame: screen)

        #expect(topLeft == CGPoint(x: 100, y: 680))
        #expect(small == CGPoint(x: 100, y: 560))
        #expect(large == CGPoint(x: 100, y: 480))
    }

    @Test func pinnedTopLeftIsClampedToScreen() {
        let origin = PopupGeometry.origin(
            topLeft: CGPoint(x: 1300, y: 100),
            size: size,
            visibleFrame: screen
        )

        #expect(origin == CGPoint(x: 1060, y: 0))
    }

    @Test func pinnedTopLeftWithoutScreenIsKept() {
        let origin = PopupGeometry.origin(
            topLeft: CGPoint(x: 5000, y: 900),
            size: size,
            visibleFrame: nil
        )

        #expect(origin == CGPoint(x: 5000, y: 700))
    }

    @Test(arguments: [
        // wider and taller: the drag goes right and down
        (CGPoint(x: 600, y: 300), CGRect(x: 100, y: 300, width: 500, height: 300)),
        // smaller than the minimum
        (CGPoint(x: 300, y: 500), CGRect(x: 100, y: 440, width: 300, height: 160)),
        // past the right and bottom screen edges
        (CGPoint(x: 5000, y: -5000), CGRect(x: 100, y: 0, width: 1340, height: 600)),
    ])
    func resizesByDraggingBottomRightCorner(dragCurrent: CGPoint, expected: CGRect) {
        let frame = PopupGeometry.resizedFrame(
            CGRect(x: 100, y: 400, width: 380, height: 200),
            dragStart: CGPoint(x: 480, y: 400),
            dragCurrent: dragCurrent,
            minSize: CGSize(width: 300, height: 160),
            visibleFrame: screen
        )

        #expect(frame == expected)
    }

    @Test(arguments: [
        (CGSize(width: 500, height: 400), CGSize(width: 500, height: 400)),
        (CGSize(width: 2000, height: 1000), CGSize(width: 1440, height: 875)),
        (CGSize(width: 100, height: 50), CGSize(width: 300, height: 160)),
    ])
    func fitsSavedSizeIntoScreen(saved: CGSize, expected: CGSize) {
        let fitted = PopupGeometry.fit(
            size: saved,
            minSize: CGSize(width: 300, height: 160),
            visibleFrame: screen
        )

        #expect(fitted == expected)
    }

    @Test(arguments: [
        (CGPoint(x: 100, y: 100), true),
        (CGPoint(x: 100.5, y: 99.5), true),
        (CGPoint(x: 101, y: 101), true),
        (CGPoint(x: 101.5, y: 100), false),
        (CGPoint(x: 100, y: 98), false),
    ])
    func comparesPositionsUpToAPoint(other: CGPoint, isSame: Bool) {
        #expect(PopupGeometry.isSamePosition(CGPoint(x: 100, y: 100), other) == isSame)
    }
}
