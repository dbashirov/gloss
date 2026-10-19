import CoreGraphics

/// PopupGeometry places the translator panel on screen. All values are in AppKit screen
/// coordinates: the origin is the bottom-left corner and y grows upwards.
public enum PopupGeometry {
    /// Distance between the cursor and the nearest panel corner.
    public static let cursorOffset: CGFloat = 12

    /// Returns the origin of a popup shown at the cursor: below and to the right of it,
    /// flipped to the left or upwards when it would cross the right or bottom screen edge.
    public static func origin(cursor: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        var origin = CGPoint(
            x: cursor.x + cursorOffset,
            y: cursor.y - cursorOffset - size.height
        )
        if origin.x + size.width > visibleFrame.maxX {
            origin.x = cursor.x - cursorOffset - size.width
        }
        if origin.y < visibleFrame.minY {
            origin.y = cursor.y + cursorOffset
        }
        return clamp(origin: origin, size: size, visibleFrame: visibleFrame)
    }

    /// Moves the origin so that the panel fits into the visible frame. A panel larger
    /// than the frame keeps its top-left corner visible: the header holds the controls.
    public static func clamp(origin: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let x = max(min(origin.x, visibleFrame.maxX - size.width), visibleFrame.minX)
        let y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        return CGPoint(x: x, y: y)
    }

    /// Returns the origin of a panel resized to `size` with its top-left corner kept
    /// in place, clamped to the visible frame.
    public static func resized(frame: CGRect, to size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let origin = CGPoint(x: frame.minX, y: frame.maxY - size.height)
        return clamp(origin: origin, size: size, visibleFrame: visibleFrame)
    }

    /// Returns the frame of a panel resized by dragging its bottom-right corner from
    /// `dragStart` to `dragCurrent`: the top-left corner stays, the size is kept between
    /// `minSize` and the room left in the visible frame.
    public static func resizedFrame(
        _ start: CGRect,
        dragStart: CGPoint,
        dragCurrent: CGPoint,
        minSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let maxWidth = max(visibleFrame.maxX - start.minX, minSize.width)
        let maxHeight = max(start.maxY - visibleFrame.minY, minSize.height)
        // y grows upwards: dragging down makes the panel taller
        let width = start.width + dragCurrent.x - dragStart.x
        let height = start.height + dragStart.y - dragCurrent.y
        let size = CGSize(
            width: min(max(width, minSize.width), maxWidth),
            height: min(max(height, minSize.height), maxHeight)
        )
        return CGRect(origin: CGPoint(x: start.minX, y: start.maxY - size.height), size: size)
    }

    /// Fits a saved panel size into the visible frame, keeping it at least `minSize`.
    public static func fit(size: CGSize, minSize: CGSize, visibleFrame: CGRect) -> CGSize {
        CGSize(
            width: max(min(size.width, visibleFrame.width), minSize.width),
            height: max(min(size.height, visibleFrame.height), minSize.height)
        )
    }

    /// Returns the origin of a panel whose top-left corner is pinned at `topLeft`:
    /// the height changes with the content, the top edge stays.
    public static func origin(topLeft: CGPoint, size: CGSize, visibleFrame: CGRect?) -> CGPoint {
        let origin = CGPoint(x: topLeft.x, y: topLeft.y - size.height)
        guard let visibleFrame else {
            return origin
        }
        return clamp(origin: origin, size: size, visibleFrame: visibleFrame)
    }

    public static func topLeft(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX, y: frame.maxY)
    }

    /// Tells whether two positions are the same up to a point: AppKit may round
    /// a frame to the pixel grid.
    public static func isSamePosition(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        abs(lhs.x - rhs.x) <= 1 && abs(lhs.y - rhs.y) <= 1
    }

    /// Returns the index of the frame that contains the point or, when none does,
    /// the closest one. `nil` only for an empty list.
    public static func nearestFrameIndex(to point: CGPoint, in frames: [CGRect]) -> Int? {
        frames.indices.min { lhs, rhs in
            distanceSquared(from: point, to: frames[lhs])
                < distanceSquared(from: point, to: frames[rhs])
        }
    }

    private static func distanceSquared(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return dx * dx + dy * dy
    }
}
