import Testing
@testable import EnglCore

@MainActor
private final class ManualClock {
    var now = ContinuousClock.now

    func advance(milliseconds: Int) {
        now += .milliseconds(milliseconds)
    }
}

@MainActor
private final class Harness {
    let pasteboard: FakePasteboard
    let clock = ManualClock()
    let watcher: ClipboardWatcher
    private(set) var received: [String] = []
    private(set) var unreadableCopies = 0

    init(changeCount: Int = 0, interval: Duration = DoubleCopyDetector.defaultInterval) {
        pasteboard = FakePasteboard(changeCount: changeCount)
        let clock = clock
        watcher = ClipboardWatcher(
            pasteboard: pasteboard,
            interval: interval,
            pollInterval: nil,
            now: { clock.now }
        )
        watcher.onDoubleCopy = { [unowned self] text in received.append(text) }
        watcher.onUnreadableCopy = { [unowned self] in unreadableCopies += 1 }
    }

    /// Copies `text` and lets the watcher see it after `milliseconds`.
    func copy(
        _ text: String?,
        types: [String]? = nil,
        changes: Int = 1,
        after milliseconds: Int = 100
    ) {
        pasteboard.copy(text, types: types, changes: changes)
        clock.advance(milliseconds: milliseconds)
        watcher.tick()
    }
}

@MainActor
struct ClipboardWatcherTests {
    @Test func startingChangeCountIsNotACopy() {
        let harness = Harness(changeCount: 42)
        harness.watcher.start()

        harness.watcher.tick()
        harness.copy("run")

        #expect(harness.received.isEmpty)
        #expect(harness.watcher.isRunning)
    }

    @Test func contentsBeforeStartAreNotCounted() {
        let harness = Harness()
        harness.pasteboard.copy("run", changes: 3)
        harness.watcher.start()

        harness.copy("run")

        #expect(harness.received.isEmpty)
    }

    @Test func doubleCopyDeliversText() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.copy("run")

        #expect(harness.received == ["run"])
    }

    // apps like Telegram clear the pasteboard and then write it: two changes per Cmd+C
    @Test func copyWithSeveralChangesIsOneCopy() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("look up", changes: 2)
        #expect(harness.received.isEmpty)

        harness.copy("look up", changes: 2)
        #expect(harness.received == ["look up"])
    }

    // a tick may fall between the clearing and the writing of one copy
    @Test func clearedPasteboardIsNotACopy() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy(nil, types: [])
        harness.copy("run")
        #expect(harness.received.isEmpty)

        harness.copy("run")
        #expect(harness.received == ["run"])
    }

    @Test func deliversLatestTextAfterDoubleCopy() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("first")
        harness.copy("second")

        #expect(harness.received == ["second"])
    }

    @Test func slowCopiesDoNotTrigger() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.copy("run", after: 600)

        #expect(harness.received.isEmpty)
    }

    @Test func usesIntervalFromSettings() {
        let harness = Harness(interval: .milliseconds(1000))
        harness.watcher.start()

        harness.copy("run")
        harness.copy("run", after: 900)
        #expect(harness.received == ["run"])

        harness.watcher.interval = .milliseconds(300)
        harness.copy("walk")
        harness.copy("walk", after: 400)
        #expect(harness.received == ["run"])
    }

    @Test func stringIsNotReadBeforeDoubleCopy() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.copy("walk", after: 700)
        harness.watcher.tick()
        #expect(harness.pasteboard.stringReads == 0)

        harness.copy("walk")
        #expect(harness.pasteboard.stringReads == 1)
    }

    @Test func nonTextContentsAreIgnored() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy(nil)
        harness.copy(nil)

        #expect(harness.received.isEmpty)
        #expect(harness.unreadableCopies == 0)
        #expect(harness.pasteboard.stringReads == 0)
    }

    @Test func blankTextIsIgnored() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy(" \n\t")
        harness.copy(" \n\t")

        #expect(harness.received.isEmpty)
        #expect(harness.unreadableCopies == 0)
    }

    @Test func unreadableTextIsReported() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy(nil, types: [PasteboardType.string])
        harness.copy(nil, types: [PasteboardType.string])

        #expect(harness.received.isEmpty)
        #expect(harness.unreadableCopies == 1)
        #expect(harness.pasteboard.stringReads == 1)
    }

    @Test func singleUnreadableCopyIsNotReported() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy(nil, types: [PasteboardType.string])

        #expect(harness.unreadableCopies == 0)
        #expect(harness.pasteboard.stringReads == 0)
    }

    @Test(arguments: [PasteboardType.concealed, PasteboardType.transient])
    func concealedContentsAreIgnored(marker: String) {
        let harness = Harness()
        harness.watcher.start()
        let types = [PasteboardType.string, marker]

        harness.copy("secret", types: types)
        harness.copy("secret", types: types)

        #expect(harness.received.isEmpty)
        #expect(harness.pasteboard.stringReads == 0)
    }

    @Test func concealedCopyResetsPendingCopy() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.copy("secret", types: [PasteboardType.string, PasteboardType.concealed])
        harness.copy("run")

        #expect(harness.received.isEmpty)
    }

    @Test func ownWriteIsIgnored() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.pasteboard.copy("бежать")
        harness.watcher.ignore(changeCount: harness.pasteboard.changeCount)
        harness.watcher.tick()

        #expect(harness.received.isEmpty)
    }

    @Test func ownWriteWithSeveralChangesIsIgnored() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.pasteboard.copy("бежать", changes: 2)
        harness.watcher.ignore(changeCount: harness.pasteboard.changeCount)
        harness.watcher.tick()

        #expect(harness.received.isEmpty)
    }

    @Test func ownWriteDoesNotHideUserCopyInSameTick() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.pasteboard.copy("бежать")
        harness.watcher.ignore(changeCount: harness.pasteboard.changeCount)
        harness.copy("walk")

        #expect(harness.received == ["walk"])
    }

    @Test func ownWriteIsIgnoredOnlyOnce() {
        let harness = Harness()
        harness.watcher.start()

        harness.pasteboard.copy("бежать")
        harness.watcher.ignore(changeCount: harness.pasteboard.changeCount)
        harness.watcher.tick()
        harness.copy("run")
        harness.copy("run")

        #expect(harness.received == ["run"])
    }

    @Test func staleIgnoreIsDropped() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.watcher.ignore(changeCount: harness.pasteboard.changeCount)
        harness.copy("run")

        #expect(harness.received == ["run"])
    }

    @Test func callbackIsNotCalledAfterStop() {
        let harness = Harness()
        harness.watcher.start()

        harness.copy("run")
        harness.watcher.stop()
        harness.copy("run")
        harness.copy("run")

        #expect(harness.received.isEmpty)
        #expect(!harness.watcher.isRunning)
        #expect(harness.pasteboard.stringReads == 0)
    }

    @Test func tickBeforeStartDoesNothing() {
        let harness = Harness()

        harness.pasteboard.copy("run", changes: 2)
        harness.watcher.tick()

        #expect(harness.received.isEmpty)
    }

    @Test func restartTakesNewBaseline() {
        let harness = Harness()
        harness.watcher.start()
        harness.watcher.stop()

        harness.pasteboard.copy("run", changes: 2)
        harness.watcher.start()
        harness.watcher.tick()
        #expect(harness.received.isEmpty)

        harness.copy("walk")
        harness.copy("walk")
        #expect(harness.received == ["walk"])
    }

    @Test func secondStartKeepsBaseline() {
        let harness = Harness()
        harness.watcher.start()

        harness.pasteboard.copy("run")
        harness.watcher.start()
        harness.watcher.tick()
        harness.copy("run")

        #expect(harness.received == ["run"])
    }

    @Test func lowerChangeCountBecomesNewBaseline() {
        let harness = Harness(changeCount: 10)
        harness.watcher.start()

        harness.pasteboard.setChangeCount(3)
        harness.watcher.tick()
        #expect(harness.received.isEmpty)

        harness.copy("run")
        harness.copy("run")
        #expect(harness.received == ["run"])
    }

    @Test func ignoreOfFutureWriteWaitsForIt() {
        let harness = Harness()
        harness.watcher.start()

        harness.watcher.ignore(changeCount: harness.pasteboard.changeCount + 1)
        harness.watcher.tick()
        harness.copy("бежать")
        harness.copy("run")
        #expect(harness.received.isEmpty)

        harness.copy("run")
        #expect(harness.received == ["run"])
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ClipboardWatcherLoopTests {
    private func makeWatcher(_ pasteboard: FakePasteboard) -> ClipboardWatcher {
        ClipboardWatcher(pasteboard: pasteboard, pollInterval: .milliseconds(1))
    }

    @Test func pollsPasteboardByItself() async {
        let pasteboard = FakePasteboard()
        let watcher = makeWatcher(pasteboard)
        let (copies, continuation) = AsyncStream.makeStream(of: String.self)
        watcher.onDoubleCopy = { continuation.yield($0) }
        watcher.start()
        defer { watcher.stop() }

        pasteboard.copy("run")
        try? await Task.sleep(for: .milliseconds(50))
        pasteboard.copy("run")

        var received: String?
        for await text in copies {
            received = text
            break
        }
        #expect(received == "run")
    }

    @Test func stopEndsPolling() async throws {
        let pasteboard = FakePasteboard()
        let watcher = makeWatcher(pasteboard)
        var received: [String] = []
        watcher.onDoubleCopy = { received.append($0) }
        watcher.start()

        watcher.stop()
        pasteboard.copy("run", changes: 2)
        try await Task.sleep(for: .milliseconds(50))

        #expect(received.isEmpty)
        #expect(pasteboard.stringReads == 0)
    }
}
