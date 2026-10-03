import Testing
import Translation
@testable import EnglCore

private struct DirectionalTranslator: TextTranslator {
    let forward: LanguageAvailability.Status
    let backward: LanguageAvailability.Status

    func status(
        from source: Language,
        to target: Language
    ) async -> LanguageAvailability.Status {
        source == .en ? forward : backward
    }

    func translate(
        _ text: String,
        from source: Language,
        to target: Language
    ) async throws -> String {
        text
    }
}

struct LanguagePackStateTests {
    @Test(arguments: [
        (LanguageAvailability.Status.installed, LanguageAvailability.Status.installed,
         LanguagePackState.installed),
        (.supported, .supported, .notInstalled),
        (.installed, .supported, .notInstalled),
        (.supported, .installed, .notInstalled),
        (.unsupported, .unsupported, .unsupported),
        (.installed, .unsupported, .unsupported),
        (.supported, .unsupported, .unsupported),
    ])
    func combinesBothDirections(
        forward: LanguageAvailability.Status,
        backward: LanguageAvailability.Status,
        expected: LanguagePackState
    ) async {
        let translator = DirectionalTranslator(forward: forward, backward: backward)

        #expect(await LanguagePackState.check(with: translator) == expected)
    }

    @Test func usesSingleStatusTranslator() async {
        let translator = FakeTextTranslator(status: .supported, translation: "")

        #expect(await LanguagePackState.check(with: translator) == .notInstalled)
    }

    @Test func hasDistinctRussianMessages() {
        let states: [LanguagePackState] = [.installed, .notInstalled, .unsupported]
        let messages = states.map(\.message)

        #expect(Set(messages).count == states.count)
        for message in messages {
            #expect(message.contains { ("а"..."я").contains(String($0).lowercased()) })
        }
    }
}
