import Observation

/// TranslationController turns raw input into a routed translation and publishes
/// the progress as `state`. A new request cancels the one in flight.
@MainActor
@Observable
public final class TranslationController {
    public enum State: Sendable, Equatable {
        case idle
        case loading
        case result(RoutedResult)
        case failed(ProviderError)
    }

    public private(set) var state: State = .idle

    @ObservationIgnored private let router: Router
    @ObservationIgnored private(set) var pending: Task<Void, Never>?

    public init(router: Router) {
        self.router = router
    }

    /// Ignores input that is empty after normalization and keeps the current state.
    public func translate(_ text: String) {
        guard let normalized = TextNormalizer.normalize(text) else {
            return
        }
        let query = QueryClassifier.classify(normalized)
        pending?.cancel()
        state = .loading
        pending = Task { [weak self, router] in
            let outcome: State
            do {
                outcome = .result(try await router.route(query))
            } catch {
                outcome = .failed(ProviderError(mapping: error))
            }
            // a cancelled request may still finish: its answer is stale
            guard !Task.isCancelled else {
                return
            }
            self?.state = outcome
        }
    }

    /// Cancels the request in flight and returns to `idle`.
    public func reset() {
        pending?.cancel()
        pending = nil
        state = .idle
    }
}
