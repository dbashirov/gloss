import Synchronization
@testable import EnglCore

/// FakeSecretStore keeps values in memory, counts calls and fails on demand.
final class FakeSecretStore: SecretStore {
    struct Failure: Error {}

    private struct State {
        var values: [String: String] = [:]
        var reads = 0
        var writes = 0
        var failsReads = false
        var failsWrites = false
    }

    private let state: Mutex<State>

    init(_ values: [String: String] = [:], failsReads: Bool = false, failsWrites: Bool = false) {
        state = Mutex(State(values: values, failsReads: failsReads, failsWrites: failsWrites))
    }

    /// A store whose every call throws `Failure`.
    static func broken() -> FakeSecretStore {
        FakeSecretStore(failsReads: true, failsWrites: true)
    }

    var reads: Int {
        state.withLock { $0.reads }
    }

    var writes: Int {
        state.withLock { $0.writes }
    }

    var failsReads: Bool {
        get { state.withLock { $0.failsReads } }
        set { state.withLock { $0.failsReads = newValue } }
    }

    func value(_ account: String) -> String? {
        state.withLock { $0.values[account] }
    }

    func read(_ account: String) throws -> String? {
        try state.withLock { state in
            state.reads += 1
            guard !state.failsReads else {
                throw Failure()
            }
            return state.values[account]
        }
    }

    func write(_ value: String?, account: String) throws {
        try state.withLock { state in
            state.writes += 1
            guard !state.failsWrites else {
                throw Failure()
            }
            state.values[account] = value?.isEmpty == false ? value : nil
        }
    }
}
