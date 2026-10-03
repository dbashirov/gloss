import Foundation
import Testing
@testable import EnglCore

struct InMemorySecretStoreTests {
    @Test func readsMissingAccountAsNil() {
        #expect(InMemorySecretStore().read("yandex-dictionary") == nil)
    }

    @Test func readsInitialValues() {
        let store = InMemorySecretStore(["yandex-dictionary": "key"])

        #expect(store.read("yandex-dictionary") == "key")
    }

    @Test func writesAndUpdatesValue() {
        let store = InMemorySecretStore()

        store.write("old", account: "yandex-dictionary")
        store.write("new", account: "yandex-dictionary")

        #expect(store.read("yandex-dictionary") == "new")
    }

    @Test(arguments: [nil, ""] as [String?])
    func removesValue(cleared: String?) {
        let store = InMemorySecretStore(["yandex-dictionary": "key", "other": "value"])

        store.write(cleared, account: "yandex-dictionary")

        #expect(store.read("yandex-dictionary") == nil)
        #expect(store.read("other") == "value")
    }

    @Test func worksThroughProtocol() throws {
        let store: any SecretStore = InMemorySecretStore()

        try store.write("key", account: "yandex-dictionary")

        #expect(try store.read("yandex-dictionary") == "key")
    }

    @Test func handlesConcurrentWrites() async {
        let store = InMemorySecretStore()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask { store.write("\(index)", account: "account-\(index)") }
            }
        }

        #expect((0..<100).allSatisfy { store.read("account-\($0)") == "\($0)" })
    }
}

struct CachedSecretStoreTests {
    @Test func readsBaseOnce() throws {
        let base = FakeSecretStore(["yandex-dictionary": "key"])
        let store = CachedSecretStore(base)

        #expect(try store.read("yandex-dictionary") == "key")
        #expect(try store.read("yandex-dictionary") == "key")
        #expect(base.reads == 1)
    }

    @Test func cachesMissingValue() throws {
        let base = FakeSecretStore()
        let store = CachedSecretStore(base)

        #expect(try store.read("yandex-dictionary") == nil)
        #expect(try store.read("yandex-dictionary") == nil)
        #expect(base.reads == 1)
    }

    @Test(arguments: [("new", "new"), ("", nil), (nil, nil)] as [(String?, String?)])
    func writeUpdatesBaseAndCache(value: String?, expected: String?) throws {
        let base = FakeSecretStore(["yandex-dictionary": "old"])
        let store = CachedSecretStore(base)
        _ = try store.read("yandex-dictionary")

        try store.write(value, account: "yandex-dictionary")

        #expect(try store.read("yandex-dictionary") == expected)
        #expect(base.value("yandex-dictionary") == expected)
        #expect(base.reads == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func writeDuringFirstReadIsNotOverwritten() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let base = FakeSecretStore(["yandex-dictionary": "old"], afterRead: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let store = CachedSecretStore(base)
        let firstRead = Task.detached { try store.read("yandex-dictionary") }
        for await _ in entered {
            break
        }

        try store.write("new", account: "yandex-dictionary")
        release.signal()
        _ = try await firstRead.value

        #expect(try store.read("yandex-dictionary") == "new")
        #expect(base.reads == 1)
    }

    @Test func failedReadIsRetried() throws {
        let base = FakeSecretStore(["yandex-dictionary": "key"], failsReads: true)
        let store = CachedSecretStore(base)

        #expect(throws: FakeSecretStore.Failure.self) {
            try store.read("yandex-dictionary")
        }
        base.failsReads = false

        #expect(try store.read("yandex-dictionary") == "key")
    }

    @Test func failedWriteKeepsCache() throws {
        let base = FakeSecretStore(["yandex-dictionary": "old"], failsWrites: true)
        let store = CachedSecretStore(base)
        _ = try store.read("yandex-dictionary")

        #expect(throws: FakeSecretStore.Failure.self) {
            try store.write("new", account: "yandex-dictionary")
        }

        #expect(try store.read("yandex-dictionary") == "old")
    }
}
