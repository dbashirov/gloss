import Testing
@testable import GlossCore

@MainActor
struct CopiedTextTests {
    @Test func readsCopiedText() {
        let pasteboard = FakePasteboard()
        pasteboard.copy("  run\n")

        #expect(pasteboard.copiedText() == .text("  run\n"))
    }

    @Test(arguments: ["", " \n\t"])
    func blankTextIsEmpty(text: String) {
        let pasteboard = FakePasteboard()
        pasteboard.copy(text)

        #expect(pasteboard.copiedText() == .empty)
    }

    @Test func contentsWithoutTextAreEmpty() {
        let pasteboard = FakePasteboard()
        pasteboard.copy(nil)

        #expect(pasteboard.copiedText() == .empty)
        #expect(pasteboard.stringReads == 0)
    }

    @Test(arguments: [PasteboardType.concealed, PasteboardType.transient])
    func concealedContentsAreNotRead(marker: String) {
        let pasteboard = FakePasteboard()
        pasteboard.copy("secret", types: [PasteboardType.string, marker])

        #expect(pasteboard.copiedText() == .empty)
        #expect(pasteboard.stringReads == 0)
    }

    @Test func deniedTextIsUnreadable() {
        let pasteboard = FakePasteboard()
        pasteboard.copy(nil, types: [PasteboardType.string])

        #expect(pasteboard.copiedText() == .unreadable)
    }
}
