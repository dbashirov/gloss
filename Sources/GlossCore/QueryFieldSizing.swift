import CoreGraphics

/// QueryFieldSizing is the math of the divider between the query field and the result:
/// the field takes the height the result area gives up, the result keeps a strip.
public enum QueryFieldSizing {
    /// The result area never gets lower than this while the divider is dragged.
    public static let minResultHeight: CGFloat = 48

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
}
