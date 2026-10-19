/// ClipboardWatcher polls the pasteboard and reports the copied text after
/// a double Cmd+C. The text is read only once the double copy is detected.
@MainActor
public final class ClipboardWatcher {
    public static let defaultPollInterval = Duration.milliseconds(100)

    /// Receives the copied text after a double copy.
    public var onDoubleCopy: ((String) -> Void)?
    /// Called after a double copy of text that could not be read, e.g. paste access is denied.
    public var onUnreadableCopy: (() -> Void)?

    public var interval: Duration {
        get { detector.interval }
        set { detector.interval = newValue }
    }

    public private(set) var isRunning = false

    private let pasteboard: any PasteboardReading
    private let pollInterval: Duration?
    private let now: () -> ContinuousClock.Instant
    private var detector: DoubleCopyDetector
    private var lastChangeCount = 0
    private var ignoredChangeCount: Int?
    private var loop: Task<Void, Never>?

    /// A `nil` `pollInterval` disables the internal loop: the owner calls `tick()`.
    public init(
        pasteboard: any PasteboardReading,
        interval: Duration = DoubleCopyDetector.defaultInterval,
        pollInterval: Duration? = defaultPollInterval,
        now: @escaping () -> ContinuousClock.Instant = { .now }
    ) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.now = now
        self.detector = DoubleCopyDetector(interval: interval)
    }

    isolated deinit {
        loop?.cancel()
    }

    /// Starts watching; whatever is already on the pasteboard is not a copy.
    public func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
        lastChangeCount = pasteboard.changeCount
        ignoredChangeCount = nil
        detector.reset()
        guard let pollInterval else {
            return
        }
        loop = Task { [weak self] in
            while !Task.isCancelled, self != nil {
                self?.tick()
                try? await Task.sleep(for: pollInterval)
            }
        }
    }

    public func stop() {
        isRunning = false
        loop?.cancel()
        loop = nil
        detector.reset()
    }

    /// Marks the app's own write to the pasteboard so it is not taken for a copy.
    public func ignore(changeCount: Int) {
        ignoredChangeCount = changeCount
    }

    public func tick() {
        guard isRunning else {
            return
        }
        var baseline = lastChangeCount
        let changeCount = pasteboard.changeCount
        lastChangeCount = changeCount
        if let ignored = ignoredChangeCount, ignored <= changeCount {
            // the own write and whatever came before it in this tick are not a copy
            baseline = max(baseline, ignored)
            ignoredChangeCount = nil
        }
        // one Cmd+C may change the pasteboard twice (clear, then write) within a tick
        guard changeCount > baseline else {
            return
        }
        let types = pasteboard.types
        // a cleared pasteboard is the middle of a copy that the next tick sees written
        guard !types.isEmpty else {
            return
        }
        let isConcealed = types.contains(PasteboardType.concealed)
            || types.contains(PasteboardType.transient)
        guard detector.register(at: now(), isConcealed: isConcealed) else {
            return
        }
        guard types.contains(PasteboardType.string) else {
            return
        }
        guard let text = pasteboard.string() else {
            onUnreadableCopy?()
            return
        }
        guard !text.allSatisfy(\.isWhitespace) else {
            return
        }
        onDoubleCopy?(text)
    }
}
