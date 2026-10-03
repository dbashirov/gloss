import Foundation
import Testing
@testable import EnglCore

private let account = YandexDictionaryProvider.keyAccount

struct CachedSecretStoreTests {
    @Test func readsBaseOnce() throws {
        let base = FakeSecretStore([account: "key"])
        let store = CachedSecretStore(base)

        #expect(try store.read(account) == "key")
        #expect(try store.read(account) == "key")
        #expect(base.reads == 1)
    }

    @Test func cachesMissingValue() throws {
        let base = FakeSecretStore()
        let store = CachedSecretStore(base)

        #expect(try store.read(account) == nil)
        #expect(try store.read(account) == nil)
        #expect(base.reads == 1)
    }

    @Test(arguments: [("new", "new"), ("", nil), (nil, nil)] as [(String?, String?)])
    func writeUpdatesBaseAndCache(value: String?, expected: String?) throws {
        let base = FakeSecretStore([account: "old"])
        let store = CachedSecretStore(base)
        _ = try store.read(account)

        try store.write(value, account: account)

        #expect(try store.read(account) == expected)
        #expect(base.value(account) == expected)
        #expect(base.reads == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func writeDuringFirstReadIsNotOverwritten() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let base = FakeSecretStore([account: "old"], afterRead: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let store = CachedSecretStore(base)
        let firstRead = Task.detached { try store.read(account) }
        for await _ in entered {
            break
        }

        try store.write("new", account: account)
        release.signal()
        _ = try await firstRead.value

        #expect(try store.read(account) == "new")
        #expect(base.reads == 1)
    }

    @Test func failedReadIsRetried() throws {
        let base = FakeSecretStore([account: "key"], failsReads: true)
        let store = CachedSecretStore(base)

        #expect(throws: FakeSecretStore.Failure.self) {
            try store.read(account)
        }
        base.failsReads = false

        #expect(try store.read(account) == "key")
    }

    @Test func failedWriteKeepsCache() throws {
        let base = FakeSecretStore([account: "old"], failsWrites: true)
        let store = CachedSecretStore(base)
        _ = try store.read(account)

        #expect(throws: FakeSecretStore.Failure.self) {
            try store.write("new", account: account)
        }

        #expect(try store.read(account) == "old")
    }
}
