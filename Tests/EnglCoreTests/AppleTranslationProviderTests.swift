import Foundation
import Testing
import Translation
@testable import EnglCore

private let hello = Query(text: "Hello, how are you?", source: .en, target: .ru, kind: .sentence)
private let word = Query(text: "бежать", source: .ru, target: .en, kind: .dictionary)

struct AppleTranslationProviderTests {
    @Test func supportsBothQueryKinds() {
        let provider = AppleTranslationProvider(translator: FakeTextTranslator(translation: ""))

        #expect(provider.id == "apple")
        #expect(provider.supports(hello))
        #expect(provider.supports(word))
    }

    @Test func translatesSentenceWhenPackIsInstalled() async throws {
        let translator = FakeTextTranslator(translation: "Привет, как дела?")
        let provider = AppleTranslationProvider(translator: translator)

        let result = try await provider.translate(hello)

        #expect(result == .text(TextTranslation(
            source: "Hello, how are you?",
            translation: "Привет, как дела?"
        )))
        #expect(translator.texts == ["Hello, how are you?"])
    }

    @Test func returnsTextForDictionaryQuery() async throws {
        let provider = AppleTranslationProvider(translator: FakeTextTranslator(translation: "run"))

        let result = try await provider.translate(word)

        #expect(result == .text(TextTranslation(source: "бежать", translation: "run")))
    }

    @Test func throwsLanguagePackMissingWhenPackIsNotDownloaded() async {
        let translator = FakeTextTranslator(status: .supported, translation: "")

        await #expect(throws: ProviderError.languagePackMissing) {
            try await AppleTranslationProvider(translator: translator).translate(hello)
        }
        #expect(translator.texts.isEmpty)
    }

    @Test func throwsNotFoundForUnsupportedPair() async {
        let translator = FakeTextTranslator(status: .unsupported, translation: "")

        await #expect(throws: ProviderError.notFound) {
            try await AppleTranslationProvider(translator: translator).translate(hello)
        }
        #expect(translator.texts.isEmpty)
    }

    @Test func mapsNotInstalledDuringTranslationToLanguagePackMissing() async {
        let translator = FakeTextTranslator(error: TranslationError.notInstalled)

        await #expect(throws: ProviderError.languagePackMissing) {
            try await AppleTranslationProvider(translator: translator).translate(hello)
        }
    }

    @Test(arguments: [
        TranslationError.unsupportedSourceLanguage,
        TranslationError.unsupportedTargetLanguage,
        TranslationError.unsupportedLanguagePairing,
        TranslationError.nothingToTranslate,
    ])
    func mapsUnsupportedLanguageErrorsToNotFound(error: TranslationError) async {
        let translator = FakeTextTranslator(error: error)

        await #expect(throws: ProviderError.notFound) {
            try await AppleTranslationProvider(translator: translator).translate(hello)
        }
    }

    @Test func mapsOtherTranslationErrorsToInvalidResponse() async {
        struct Unexpected: Error {}
        for error in [TranslationError.internalError, Unexpected()] as [any Error & Sendable] {
            let translator = FakeTextTranslator(error: error)

            await #expect(throws: ProviderError.invalidResponse) {
                try await AppleTranslationProvider(translator: translator).translate(hello)
            }
        }
    }
}

struct AppleTranslationProviderCancellationTests {
    @Test(arguments: [
        TranslationError.alreadyCancelled,
        CancellationError(),
    ] as [any Error & Sendable])
    func mapsCancelledTranslationToCancellationError(error: any Error & Sendable) async {
        let translator = FakeTextTranslator(error: error)

        await #expect(throws: CancellationError.self) {
            try await AppleTranslationProvider(translator: translator).translate(hello)
        }
    }

    @Test func throwsCancellationWhenTaskIsCancelledDuringTranslation() async {
        let translator = FakeTextTranslator { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            throw TranslationError.internalError
        }

        await #expect(throws: CancellationError.self) {
            try await AppleTranslationProvider(translator: translator).translate(hello)
        }
    }

    @Test func cancelsInFlightTranslation() async {
        let translator = FakeTextTranslator { _ in
            try await Task.sleep(for: .seconds(60))
            return ""
        }
        let provider = AppleTranslationProvider(translator: translator)
        let task = Task { try await provider.translate(hello) }

        while translator.texts.isEmpty {
            await Task.yield()
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}

private func packIsInstalled() async -> Bool {
    await SystemTextTranslator().status(from: .en, to: .ru) == .installed
}

@Suite(.enabled("needs the installed en↔ru language pack", packIsInstalled))
struct SystemTextTranslatorIntegrationTests {
    @Test func translatesWithInstalledPack() async throws {
        let provider = AppleTranslationProvider(translator: SystemTextTranslator())
        let query = Query(text: "Good morning", source: .en, target: .ru, kind: .sentence)

        let result = try await provider.translate(query)

        guard case .text(let text) = result else {
            Issue.record("expected a text translation, got \(result)")
            return
        }
        #expect(!text.translation.isEmpty)
        #expect(text.translation != "Good morning")
    }
}
