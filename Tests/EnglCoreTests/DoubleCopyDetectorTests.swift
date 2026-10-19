import Testing
@testable import EnglCore

private let start = ContinuousClock.now

private struct Change {
    let milliseconds: Int
    let isConcealed: Bool
}

private func copy(at milliseconds: Int, concealed: Bool = false) -> Change {
    Change(milliseconds: milliseconds, isConcealed: concealed)
}

/// Feeds the changes to the detector and returns whether each one triggered.
private func triggers(_ changes: [Change], detector: inout DoubleCopyDetector) -> [Bool] {
    changes.map { change in
        detector.register(
            at: start + .milliseconds(change.milliseconds),
            isConcealed: change.isConcealed
        )
    }
}

private func triggers(_ changes: [Change]) -> [Bool] {
    var detector = DoubleCopyDetector()
    return triggers(changes, detector: &detector)
}

struct DoubleCopyDetectorTests {
    @Test func triggersOnTwoChangesWithinInterval() {
        #expect(triggers([copy(at: 0), copy(at: 400)]) == [false, true])
    }

    @Test func triggersOnChangeExactlyAtIntervalBoundary() {
        #expect(triggers([copy(at: 0), copy(at: 500)]) == [false, true])
    }

    @Test func doesNotTriggerOutsideInterval() {
        #expect(triggers([copy(at: 0), copy(at: 501)]) == [false, false])
    }

    @Test func lateChangeStartsNewWindow() {
        let changes = [copy(at: 0), copy(at: 800), copy(at: 1100)]

        #expect(triggers(changes) == [false, false, true])
    }

    @Test func thirdChangeDoesNotTriggerAgain() {
        let changes = [copy(at: 0), copy(at: 100), copy(at: 200)]

        #expect(triggers(changes) == [false, true, false])
    }

    @Test func concealedChangeResetsPendingCopy() {
        let changes = [copy(at: 0), copy(at: 100, concealed: true), copy(at: 200), copy(at: 300)]

        #expect(triggers(changes) == [false, false, false, true])
    }

    @Test func concealedCopiesDoNotTrigger() {
        let changes = [copy(at: 0, concealed: true), copy(at: 100, concealed: true)]

        #expect(triggers(changes) == [false, false])
    }

    @Test func resetForgetsPendingCopy() {
        var detector = DoubleCopyDetector()

        #expect(triggers([copy(at: 0)], detector: &detector) == [false])
        detector.reset()
        #expect(triggers([copy(at: 100)], detector: &detector) == [false])
    }

    @Test func usesConfiguredInterval() {
        var detector = DoubleCopyDetector(interval: .milliseconds(800))

        #expect(triggers([copy(at: 0), copy(at: 700)], detector: &detector) == [false, true])

        detector.interval = .milliseconds(300)
        let changes = [copy(at: 1000), copy(at: 1400)]
        #expect(triggers(changes, detector: &detector) == [false, false])
    }

    @Test(arguments: [
        (Duration.milliseconds(100), Duration.milliseconds(300)),
        (.milliseconds(300), .milliseconds(300)),
        (.milliseconds(650), .milliseconds(650)),
        (.milliseconds(1000), .milliseconds(1000)),
        (.seconds(5), .milliseconds(1000)),
    ])
    func clampsInterval(requested: Duration, expected: Duration) {
        var detector = DoubleCopyDetector(interval: requested)
        #expect(detector.interval == expected)

        detector.interval = requested
        #expect(detector.interval == expected)
    }

    @Test func defaultIntervalIsHalfSecond() {
        #expect(DoubleCopyDetector().interval == .milliseconds(500))
    }
}
