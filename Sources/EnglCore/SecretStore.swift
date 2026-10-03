import Synchronization

/// SecretStore keeps small secrets such as API keys, addressed by account name.
public protocol SecretStore: Sendable {
    /// Returns the stored value or `nil` when the account has none.
    func read(_ account: String) throws -> String?
    /// Stores the value; `nil` or an empty string removes the account's secret.
    func write(_ value: String?, account: String) throws
}

/// InMemorySecretStore is a process-local `SecretStore` for tests and previews.
public final class InMemorySecretStore: SecretStore {
    private let values: Mutex<[String: String]>

    public init(_ values: [String: String] = [:]) {
        self.values = Mutex(values)
    }

    public func read(_ account: String) -> String? {
        values.withLock { $0[account] }
    }

    public func write(_ value: String?, account: String) {
        values.withLock { stored in
            if let value, !value.isEmpty {
                stored[account] = value
            } else {
                stored[account] = nil
            }
        }
    }
}
