import Foundation

/// YandexKeyStore reads and replaces the Yandex Dictionary key; a new key drops
/// the router cache so answers given under the old key are not reused.
public struct YandexKeyStore: Sendable {
    private let secrets: any SecretStore
    private let router: Router

    public init(secrets: any SecretStore, router: Router) {
        self.secrets = secrets
        self.router = router
    }

    /// Returns the stored key or an empty string. Runs off the caller's actor:
    /// a Keychain read may wait for an access prompt.
    @concurrent
    public func load() async throws -> String {
        try secrets.read(YandexDictionaryProvider.keyAccount) ?? ""
    }

    /// Stores the trimmed key and returns it; an empty key removes the stored one.
    /// Runs off the caller's actor, like `load()`.
    @discardableResult
    @concurrent
    public func save(_ key: String) async throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try secrets.write(trimmed, account: YandexDictionaryProvider.keyAccount)
        await router.invalidate()
        return trimmed
    }
}
