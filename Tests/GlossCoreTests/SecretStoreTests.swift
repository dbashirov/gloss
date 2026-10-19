import Testing
@testable import GlossCore

struct SecretStoreTests {
    @Test(arguments: [("key", "key"), (" ", " "), ("", nil), (nil, nil)] as [(String?, String?)])
    func storedValueDropsOnlyMissingAndEmptyValues(value: String?, expected: String?) {
        #expect(InMemorySecretStore.storedValue(value) == expected)
    }
}
