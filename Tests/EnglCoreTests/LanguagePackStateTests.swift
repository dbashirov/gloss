import Testing
import Translation
@testable import EnglCore

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
        let translator = FakeTextTranslator(statuses: [.enRu: forward, .ruEn: backward]) { $0 }

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
