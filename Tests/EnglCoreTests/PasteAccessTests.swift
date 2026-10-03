import Testing
@testable import EnglCore

struct PasteAccessTests {
    @Test func statusesAreDistinct() {
        let statuses = Set(PasteAccess.allCases.map(\.status))
        #expect(statuses.count == PasteAccess.allCases.count)
    }

    @Test func onlyAllowedAccessNeedsNoHint() {
        #expect(PasteAccess.allowed.hint == nil)
        #expect(PasteAccess.denied.hint?.contains("Вставка из других приложений") == true)
        #expect(PasteAccess.ask.hint?.contains("Разрешать всегда") == true)
    }
}
