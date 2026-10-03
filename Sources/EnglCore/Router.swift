/// Router answers a query from its cache or from the first provider in the chain
/// that succeeds.
public actor Router {
    public static let defaultCacheLimit = 500

    private let providers: [any TranslationProvider]
    private let cacheLimit: Int
    private var cache: [Query: RoutedResult] = [:]
    private var insertionOrder: [Query] = []
    private var generation = 0

    public init(providers: [any TranslationProvider], cacheLimit: Int = defaultCacheLimit) {
        self.providers = providers
        self.cacheLimit = max(cacheLimit, 0)
    }

    /// Tries providers in order, moving on after any `ProviderError`. Other errors,
    /// including `CancellationError`, stop the chain. When nobody answers, throws
    /// the most useful of the collected errors.
    public func route(_ query: Query) async throws -> RoutedResult {
        if let cached = cache[query] {
            return cached
        }
        let startGeneration = generation
        var failures: [ProviderError] = []
        for provider in providers where provider.supports(query) {
            try Task.checkCancellation()
            do {
                let result = try await provider.translate(query)
                let routed = RoutedResult(providerID: provider.id, result: result)
                // a fallback answer must not shadow the preferred provider later;
                // a result started before invalidate() may be stale
                if failures.isEmpty && startGeneration == generation {
                    store(routed, for: query)
                }
                return routed
            } catch let error as ProviderError {
                failures.append(error)
            }
        }
        throw Self.mostUseful(failures) ?? .notConfigured
    }

    /// Drops cached results, e.g. after the API key has changed.
    public func invalidate() {
        cache.removeAll()
        insertionOrder.removeAll()
        generation += 1
    }

    private func store(_ result: RoutedResult, for query: Query) {
        guard cacheLimit > 0 else {
            return
        }
        if cache.updateValue(result, forKey: query) != nil {
            return
        }
        insertionOrder.append(query)
        while insertionOrder.count > cacheLimit {
            cache[insertionOrder.removeFirst()] = nil
        }
    }

    /// Picks the error with the highest priority; the earliest one wins a tie.
    static func mostUseful(_ errors: [ProviderError]) -> ProviderError? {
        errors.max { $0.priority < $1.priority }
    }
}

private extension ProviderError {
    var priority: Int {
        switch self {
        case .invalidKey, .rateLimited, .languagePackMissing:
            3
        case .network, .invalidResponse:
            2
        case .notConfigured:
            1
        case .notFound:
            0
        }
    }
}
