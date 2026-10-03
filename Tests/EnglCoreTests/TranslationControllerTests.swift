import Testing
@testable import EnglCore

private let runQuery = Query(text: "run", source: .en, target: .ru, kind: .dictionary)
private let runCard = TranslationResult.dictionary(DictionaryEntry(
    word: "run",
    transcription: "rʌn",
    groups: [PartOfSpeechGroup(partOfSpeech: "verb", translations: [Sense(text: "бежать")])]
))
private let walkText = TranslationResult.text(TextTranslation(source: "walk", translation: "идти"))

private struct UnexpectedError: Error {}

@MainActor
private func makeController(_ providers: [any TranslationProvider]) -> TranslationController {
    TranslationController(router: Router(providers: providers))
}

@MainActor
struct TranslationControllerTests {
    @Test func startsIdle() {
        let controller = makeController([FakeProvider(id: "yandex", result: runCard)])

        #expect(controller.state == .idle)
    }

    @Test func publishesResult() async {
        let provider = FakeProvider(id: "yandex", result: runCard)
        let controller = makeController([provider])

        controller.translate("  run\n")
        #expect(controller.state == .loading(runQuery))
        await controller.pending?.value

        #expect(controller.state == .result(RoutedResult(providerID: "yandex", result: runCard)))
        #expect(provider.calls == 1)
    }

    @Test func classifiesNormalizedSentence() async {
        let provider = FakeProvider(id: "apple", result: walkText)
        let controller = makeController([provider])

        controller.translate("Я   иду\tдомой.")

        let expected = Query(text: "Я иду домой.", source: .ru, target: .en, kind: .sentence)
        #expect(controller.state == .loading(expected))
        await controller.pending?.value
    }

    @Test func publishesFailureWithNormalizedText() async {
        let controller = makeController([FakeProvider(id: "yandex", error: ProviderError.invalidKey)])

        controller.translate(" run  ")
        await controller.pending?.value

        #expect(controller.state == .failed(text: "run", error: .invalidKey))
    }

    @Test func mapsUnexpectedErrorToInvalidResponse() async {
        let controller = makeController([FakeProvider(id: "yandex", error: UnexpectedError())])

        controller.translate("run")
        await controller.pending?.value

        #expect(controller.state == .failed(text: "run", error: .invalidResponse))
    }

    @Test(arguments: ["", "   ", "\n\t "])
    func emptyInputKeepsState(input: String) async {
        let provider = FakeProvider(id: "yandex", result: runCard)
        let controller = makeController([provider])
        controller.translate("run")
        await controller.pending?.value
        let before = controller.state

        controller.translate(input)
        await controller.pending?.value

        #expect(controller.state == before)
        #expect(provider.calls == 1)
    }

    @Test func emptyInputDoesNotCancelRequestInFlight() async {
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let provider = FakeProvider(id: "yandex") { _ in
            for await _ in gate {
                break
            }
            return runCard
        }
        let controller = makeController([provider])
        controller.translate("run")
        let pending = controller.pending

        controller.translate(" ")
        gateContinuation.yield()
        await pending?.value

        #expect(controller.state == .result(RoutedResult(providerID: "yandex", result: runCard)))
    }

    @Test func cancellationErrorKeepsState() async {
        let controller = makeController([FakeProvider(id: "yandex", error: CancellationError())])

        controller.translate("run")
        await controller.pending?.value

        #expect(controller.state == .loading(runQuery))
    }

    @Test func secondRequestCancelsFirst() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let provider = FakeProvider(id: "yandex") { query in
            guard query.text == "run" else {
                return walkText
            }
            enteredContinuation.yield()
            for await _ in gate {
                break
            }
            return runCard
        }
        let controller = makeController([provider])

        controller.translate("run")
        let first = controller.pending
        for await _ in entered {
            break
        }
        controller.translate("walk")
        await controller.pending?.value
        gateContinuation.yield()
        await first?.value

        #expect(controller.state == .result(RoutedResult(providerID: "yandex", result: walkText)))
        #expect(provider.calls == 2)
    }

    @Test func cancelledRequestFailureIsDropped() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let (finished, finishedContinuation) = AsyncStream.makeStream(of: Void.self)
        let provider = FakeProvider(id: "yandex") { query in
            guard query.text == "run" else {
                for await _ in finished {
                    break
                }
                return walkText
            }
            enteredContinuation.yield()
            for await _ in gate {
                break
            }
            throw ProviderError.network
        }
        let controller = makeController([provider])

        controller.translate("run")
        let first = controller.pending
        for await _ in entered {
            break
        }
        controller.translate("walk")
        gateContinuation.yield()
        await first?.value

        #expect(controller.state == .loading(Query(
            text: "walk", source: .en, target: .ru, kind: .dictionary
        )))
        finishedContinuation.yield()
        await controller.pending?.value
    }

    @Test func resetCancelsRequestAndReturnsToIdle() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let provider = FakeProvider(id: "yandex") { _ in
            enteredContinuation.yield()
            try await Task.sleep(for: .seconds(60))
            return runCard
        }
        let controller = makeController([provider])
        controller.translate("run")
        let pending = controller.pending
        for await _ in entered {
            break
        }

        controller.reset()
        await pending?.value

        #expect(controller.state == .idle)
        #expect(controller.pending == nil)
    }
}
