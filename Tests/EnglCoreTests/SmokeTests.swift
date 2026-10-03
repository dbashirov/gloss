import Testing
@testable import EnglCore

struct SmokeTests {
    @Test func versionIsSet() {
        #expect(EnglCore.version == "0.1.0")
    }
}
