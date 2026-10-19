import Synchronization

/// SecretStore keeps small secrets such as API keys, addressed by account name.
public protocol SecretStore: Sendable {
    /// Returns the stored value or `nil` when the account has none.
    func read(_ account: String) throws -> String?
    /// Stores the value; `nil` or an empty string removes the account's secret.
    func write(_ value: String?, account: String) throws
}

extension SecretStore {
    /// Returns the value a write stores: `nil` for a missing or empty one.
    public static func storedValue(_ value: String?) -> String? {
        value?.isEmpty == false ? value : nil
    }
}

/// CachedSecretStore remembers what it has read or written, so the store behind it is
/// asked once per account: Keychain may show an access prompt on every read of an item
/// created by a previous build of an ad-hoc signed app. Failed reads are not cached.
/// Writes are expected from one caller at a time (the settings window serializes saves).
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
        // a write that finished while the base was being read wins over the older value
        return cache.withLock { cache in
            if let cached = cache[account] {
                return cached
            }
            cache[account] = .some(value)
            return value
        }
    }

    public func write(_ value: String?, account: String) throws {
        try base.write(value, account: account)
        cache.withLock { $0[account] = .some(Self.storedValue(value)) }
    }
}

/// InMemorySecretStore is a process-local `SecretStore`, e.g. for checking a key
/// without storing it.
public final class InMemorySecretStore: SecretStore {
    private let values: Mutex<[String: String]>

    public init(_ values: [String: String] = [:]) {
        self.values = Mutex(values)
    }

    public func read(_ account: String) -> String? {
        values.withLock { $0[account] }
    }

    public func write(_ value: String?, account: String) {
        values.withLock { $0[account] = Self.storedValue(value) }
    }
}
