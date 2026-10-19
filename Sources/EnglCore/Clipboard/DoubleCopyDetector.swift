/// DoubleCopyDetector recognises a double Cmd+C from pasteboard changes.
public struct DoubleCopyDetector: Sendable {
    public static let defaultInterval = Duration.milliseconds(500)
    public static let intervalRange = Duration.milliseconds(300)...Duration.milliseconds(1000)

    /// Maximum time between two copies that still counts as a double copy.
    public var interval: Duration {
        didSet { interval = Self.clamp(interval) }
    }

    private var lastChange: ContinuousClock.Instant?

    public init(interval: Duration = defaultInterval) {
        self.interval = Self.clamp(interval)
    }

    /// Registers a copy seen at `instant` and returns `true` when it completes a double
    /// copy. Concealed or transient contents reset the detector.
    public mutating func register(at instant: ContinuousClock.Instant, isConcealed: Bool) -> Bool {
        if isConcealed {
            reset()
            return false
        }
        if let lastChange, instant - lastChange <= interval {
            reset()
            return true
        }
        lastChange = instant
        return false
    }

    public mutating func reset() {
        lastChange = nil
    }

    private static func clamp(_ interval: Duration) -> Duration {
        min(max(interval, intervalRange.lowerBound), intervalRange.upperBound)
    }
}
