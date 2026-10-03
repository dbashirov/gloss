import Testing
@testable import EnglCore

private func isRussian(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
}

struct ProviderErrorMessageTests {
    @Test(arguments: ProviderError.allCases)
    func everyErrorHasRussianMessage(error: ProviderError) {
        #expect(isRussian(error.message))
    }

    @Test func messagesAreDistinct() {
        let messages = Set(ProviderError.allCases.map(\.message))
        #expect(messages.count == ProviderError.allCases.count)
    }

    @Test(arguments: [
        (ProviderError.notConfigured, ErrorAction?.some(.openSettings)),
        (.invalidKey, .openSettings),
        (.languagePackMissing, .downloadLanguagePack),
        (.notFound, nil),
        (.rateLimited, nil),
        (.network, nil),
        (.invalidResponse, nil),
        (.keyUnavailable, .openSettings),
    ])
    func mapsErrorToAction(error: ProviderError, action: ErrorAction?) {
        #expect(error.action == action)
    }

    @Test(arguments: ErrorAction.allCases)
    func everyActionHasRussianTitle(action: ErrorAction) {
        #expect(isRussian(action.title))
    }

    @Test func actionTitlesAreDistinct() {
        let titles = Set(ErrorAction.allCases.map(\.title))
        #expect(titles.count == ErrorAction.allCases.count)
    }
}
