import Foundation
import Synchronization
import Testing
import Translation
@testable import GlossCore

private let hello = Query(text: "Hello, how are you?", source: .en, target: .ru, kind: .sentence)
private let word = Query(text: "бежать", source: .ru, target: .en, kind: .dictionary)

private func noDelayProvider(_ translator: FakeTextTranslator) -> AppleTranslationProvider {
    AppleTranslationProvider(translator: translator, packRetryDelay: .zero)
}

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

    @Test func translatesParagraphsSeparately() async throws {
        let translator = FakeTextTranslator { "<\($0)>" }
        let provider = AppleTranslationProvider(translator: translator)
        let text = "One.\nTwo.\n\nThree"
        let query = Query(text: text, source: .en, target: .ru, kind: .sentence)

        let result = try await provider.translate(query)

        let translation = "<One.>\n<Two.>\n\n<Three>"
        #expect(result == .text(TextTranslation(source: text, translation: translation)))
        #expect(translator.texts == ["One.", "Two.", "Three"])
        #expect(translator.translateDirections.count == 1)
    }

    @Test func returnsTextForDictionaryQuery() async throws {
        let provider = AppleTranslationProvider(translator: FakeTextTranslator(translation: "run"))

        let result = try await provider.translate(word)

        #expect(result == .text(TextTranslation(source: "бежать", translation: "run")))
    }

    @Test(arguments: [hello, word])
    func usesQueryDirection(query: Query) async throws {
        let translator = FakeTextTranslator(translation: "")

        _ = try await AppleTranslationProvider(translator: translator).translate(query)

        let direction = FakeTextTranslator.Direction(source: query.source, target: query.target)
        #expect(translator.statusDirections == [direction])
        #expect(translator.translateDirections == [direction])
    }

    @Test func throwsLanguagePackMissingWhenPackIsNotDownloaded() async {
        let translator = FakeTextTranslator(status: .supported, translation: "")

        await #expect(throws: ProviderError.languagePackMissing) {
            try await noDelayProvider(translator).translate(hello)
        }
        #expect(translator.statusDirections == [.enRu, .enRu])
        #expect(translator.texts.isEmpty)
    }

    @Test func translatesWhenPackTurnsUpOnSecondCheck() async throws {
        let translator = FakeTextTranslator(
            firstStatuses: [.supported],
            translation: "Привет"
        )

        let result = try await noDelayProvider(translator).translate(hello)

        #expect(result == .text(TextTranslation(source: hello.text, translation: "Привет")))
        #expect(translator.statusDirections == [.enRu, .enRu])
        #expect(translator.texts == [hello.text])
    }

    @Test func throwsNotFoundForUnsupportedPair() async {
        let translator = FakeTextTranslator(status: .unsupported, translation: "")

        await #expect(throws: ProviderError.notFound) {
            try await AppleTranslationProvider(translator: translator).translate(hello)
        }
        #expect(translator.statusDirections == [.enRu])
        #expect(translator.texts.isEmpty)
    }

    @Test func mapsNotInstalledDuringTranslationToLanguagePackMissing() async {
        let translator = FakeTextTranslator(error: TranslationError.notInstalled)

        await #expect(throws: ProviderError.languagePackMissing) {
            try await noDelayProvider(translator).translate(hello)
        }
        #expect(translator.texts == [hello.text, hello.text])
    }

    @Test func translatesWhenNotInstalledClearsOnSecondAttempt() async throws {
        let attempts = Mutex(0)
        let translator = FakeTextTranslator { text in
            let attempt = attempts.withLock { count in
                count += 1
                return count
            }
            guard attempt > 1 else {
                throw TranslationError.notInstalled
            }
            return "<\(text)>"
        }

        let result = try await noDelayProvider(translator).translate(hello)

        let translation = "<\(hello.text)>"
        #expect(result == .text(TextTranslation(source: hello.text, translation: translation)))
        #expect(translator.texts == [hello.text, hello.text])
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
            #expect(translator.texts == [hello.text])
        }
    }
}

@Suite(.timeLimit(.minutes(1)))
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
        let provider = AppleTranslationProvider(translator: translator)
        // cancels its own task, not the one running the test
        let task = Task { try await provider.translate(hello) }

        await #expect(throws: CancellationError.self) {
            try await task.value
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

    @Test func cancelsWhileWaitingToCheckPackAgain() async {
        let translator = FakeTextTranslator(status: .supported, translation: "")
        let provider = AppleTranslationProvider(
            translator: translator,
            packRetryDelay: .seconds(60)
        )
        let task = Task { try await provider.translate(hello) }

        while translator.statusDirections.isEmpty {
            await Task.yield()
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(translator.statusDirections == [.enRu])
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

    @Test func keepsParagraphsWithInstalledPack() async throws {
        let provider = AppleTranslationProvider(translator: SystemTextTranslator())
        let source = "Good morning.\n\nSee you tomorrow."
        let query = Query(text: source, source: .en, target: .ru, kind: .sentence)

        let result = try await provider.translate(query)

        guard case .text(let text) = result else {
            Issue.record("expected a text translation, got \(result)")
            return
        }
        let paragraphs = text.translation.components(separatedBy: "\n\n")
        #expect(paragraphs.count == 2)
        #expect(paragraphs.allSatisfy { !$0.isEmpty && !$0.contains("\n") })
    }
}
