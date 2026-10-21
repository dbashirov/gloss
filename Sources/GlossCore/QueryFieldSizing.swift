import CoreGraphics

/// QueryFieldSizing is the math of the divider between the query field and the result:
/// the field takes the height the result area gives up, the result keeps a strip.
public enum QueryFieldSizing {
    /// The result area never gets lower than this while the divider is dragged.
    public static let minResultHeight: CGFloat = 48
    /// The share of the room the field takes in a panel sized by the user until the
    /// divider is dragged: the divider stands in the middle.
    public static let defaultShare = 0.5

    /// Returns the field height after the divider moved `offset` points down from where
    /// the drag began. `resultRoom` is how high the result area could be at that moment.
    public static func height(
        dragging startHeight: CGFloat,
        by offset: CGFloat,
        minHeight: CGFloat,
        resultRoom: CGFloat
    ) -> CGFloat {
        let maxHeight = max(minHeight, startHeight + resultRoom - minResultHeight)
        return min(max(startHeight + offset, minHeight), maxHeight)
    }

    /// Returns the field height for `share` of `room`, the height of the field and the
    /// result area together, so the divider keeps its place as the panel is resized.
    public static func height(share: Double, room: CGFloat, minHeight: CGFloat) -> CGFloat {
        let maxHeight = max(minHeight, room - minResultHeight)
        return min(max(room * share, minHeight), maxHeight)
    }

    /// Returns the share of `room` a field of `height` takes; `nil` when there is no room
    /// yet, before the first layout.
    public static func share(of height: CGFloat, room: CGFloat) -> Double? {
        room > 0 ? min(max(Double(height / room), 0), 1) : nil
    }
}
