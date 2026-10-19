@testable import GlossCore

@MainActor
final class FakePasteboard: PasteboardReading {
    private(set) var changeCount: Int
    private(set) var types: [String] = []
    private(set) var stringReads = 0
    private var text: String?

    init(changeCount: Int = 0) {
        self.changeCount = changeCount
    }

    func string() -> String? {
        stringReads += 1
        return text
    }

    /// Sets `changeCount` directly, e.g. to a lower value after a pasteboard reset.
    func setChangeCount(_ changeCount: Int) {
        self.changeCount = changeCount
    }

    /// Simulates a copy: replaces the contents and bumps `changeCount` by `changes`.
    func copy(_ text: String?, types: [String]? = nil, changes: Int = 1) {
        self.text = text
        self.types = types ?? (text == nil ? ["public.png"] : [PasteboardType.string])
        changeCount += changes
    }
}
