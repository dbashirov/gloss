import Synchronization

/// SecretStore keeps small secrets such as API keys, addressed by account name.
public protocol SecretStore: Sendable {
    /// Returns the stored value or `nil` when the account has none.
    func read(_ account: String) throws -> String?
    /// Stores the value; `nil` or an empty string removes the account's secret.
    func write(_ value: String?, account: String) throws
}

/// CachedSecretStore remembers what it has read or written, so the store behind it is
/// asked once per account: Keychain may show an access prompt on every read of an item
/// created by a previous build of an ad-hoc signed app. Failed reads are not cached.
public final class CachedSecretStore: SecretStore {
    private let base: any SecretStore
    private let cache = Mutex<[String: String?]>([:])

    public init(_ base: any SecretStore) {
        self.base = base
    }

    public func read(_ account: String) throws -> String? {
        if let cached = cache.withLock({ $0[account] }) {
            return cached
        }
        let value = try base.read(account)
        cache.withLock { $0[account] = .some(value) }
        return value
    }

    public func write(_ value: String?, account: String) throws {
        try base.write(value, account: account)
        let stored = value?.isEmpty == false ? value : nil
        cache.withLock { $0[account] = .some(stored) }
    }
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
