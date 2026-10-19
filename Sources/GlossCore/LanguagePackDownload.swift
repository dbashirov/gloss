import Translation

/// LanguagePackDownload is the state of the en↔ru pack download run by a view's
/// `.translationTask`. Every request gets a new ID, so a cancelled task that finishes
/// late leaves a newer request alone.
public struct LanguagePackDownload {
    /// Set while a download runs; the `.translationTask` restarts whenever it changes.
    public private(set) var configuration: TranslationSession.Configuration?
    /// The ID the current task must report to `finish(requestID:)`.
    public private(set) var requestID = 0

    public var isActive: Bool {
        configuration != nil
    }

    public init() {}

    /// Starts a download, or restarts the running one so its task carries the new ID.
    public mutating func start() {
        requestID += 1
        guard configuration != nil else {
            configuration = TranslationSession.Configuration(
                source: Language.en.locale,
                target: Language.ru.locale
            )
            return
        }
        // an equal configuration would not restart the task with the new ID
        configuration?.invalidate()
    }

    /// Ends the current download; returns false for a stale task, whose finish is ignored.
    public mutating func finish(requestID: Int) -> Bool {
        guard isActive, requestID == self.requestID else {
            return false
        }
        configuration = nil
        return true
    }
}
