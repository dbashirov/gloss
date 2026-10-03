import Foundation
import Observation
import os

/// YandexKeySettings is the state of the API key field in the settings window:
/// the draft, the outcome of the last save or check and the read or check in progress.
@MainActor
@Observable
public final class YandexKeySettings {
    public private(set) var note: SettingsNote? {
        didSet { isCheckNote = false }
    }
    public private(set) var isChecking = false
    /// `true` while the stored key is being read: Keychain may wait for an access prompt.
    public private(set) var isLoading = false
    /// `false` until the key was read and after a failed read: the key may still be stored,
    /// so an empty draft must not delete it.
    public private(set) var isLoaded = false

    /// The key as entered; an edit drops the check of the previous draft.
    public var draft: String {
        get { enteredDraft }
        set {
            guard newValue != enteredDraft else {
                return
            }
            enteredDraft = newValue
            dropCheck()
        }
    }

    private var enteredDraft = ""
    @ObservationIgnored private let store: YandexKeyStore
    @ObservationIgnored private let keyCheck: YandexKeyCheck
    @ObservationIgnored private let logger = Logger(
        subsystem: AppIdentity.bundleID,
        category: "settings"
    )
    @ObservationIgnored private(set) var loadTask: Task<Void, Never>?
    @ObservationIgnored private(set) var checkTask: Task<Void, Never>?
    @ObservationIgnored private(set) var saveTask: Task<Void, Never>?
    /// The draft as `load()` or a finished save set it; `nil` from the start of a save,
    /// so what the user typed is never replaced.
    @ObservationIgnored private var syncedDraft: String?
    /// Whether `note` is the outcome of a check, which an edit or a save makes stale.
    @ObservationIgnored private var isCheckNote = false

    public init(store: YandexKeyStore, keyCheck: YandexKeyCheck) {
        self.store = store
        self.keyCheck = keyCheck
    }

    public var canSave: Bool {
        isLoaded || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `false` while the stored key is being read: the draft is not the key yet.
    public var canCheck: Bool {
        !isLoading && !isChecking
    }

    /// Drops the state of the previous visit and reads the stored key into the draft
    /// off the main actor. What the user types meanwhile is kept; a save still in flight
    /// replaces the value read here when it finishes.
    public func load() {
        loadTask?.cancel()
        dropCheck()
        note = nil
        isLoaded = false
        isLoading = true
        enteredDraft = ""
        syncedDraft = ""
        loadTask = Task {
            let result: Result<String, any Error>
            do {
                result = .success(try await store.load())
            } catch {
                result = .failure(error)
            }
            // a newer load or a finished save has taken over
            guard !Task.isCancelled else {
                return
            }
            finishLoad(with: result)
        }
    }

    public func save() {
        guard canSave else {
            return
        }
        let key = draft
        syncedDraft = nil
        dropCheck()
        // saves run one after another, so the last one pressed is the one stored
        let previous = saveTask
        saveTask = Task {
            await previous?.value
            let saved: String
            do {
                saved = try await store.save(key)
            } catch {
                let reason = error.localizedDescription
                logger.error("saving the key failed: \(reason, privacy: .public)")
                note = .failure("Не удалось сохранить ключ в Связку ключей")
                return
            }
            // the stored key is newer than anything a read still in flight returns
            loadTask?.cancel()
            isLoading = false
            isLoaded = true
            // keep what the user typed meanwhile, but not a value read before the save ended
            if draft == key || draft == syncedDraft {
                enteredDraft = saved
                syncedDraft = saved
            }
            note = .success(saved.isEmpty ? "Ключ удалён" : "Ключ сохранён")
        }
    }

    /// Checks the draft with a real request without saving it.
    /// Does nothing while the stored key is being read.
    public func check() {
        guard !isLoading else {
            return
        }
        dropCheck()
        let key = draft
        note = nil
        isChecking = true
        checkTask = Task {
            let outcome: SettingsNote
            do {
                try await keyCheck.check(key)
                outcome = .success("Ключ действителен")
            } catch {
                outcome = .failure(ProviderError(mapping: error).message)
            }
            // a newer check, an edit, a save or a reload has taken over
            guard !Task.isCancelled else {
                return
            }
            note = outcome
            isCheckNote = true
            isChecking = false
        }
    }

    private func finishLoad(with result: Result<String, any Error>) {
        isLoading = false
        // the user typed while the key was being read
        let isEdited = draft != syncedDraft
        switch result {
        case let .success(stored):
            isLoaded = true
            syncedDraft = stored
            if !isEdited {
                enteredDraft = stored
            }
        case let .failure(error):
            let reason = error.localizedDescription
            logger.error("reading the key failed: \(reason, privacy: .public)")
            note = .failure("Не удалось прочитать ключ из Связки ключей")
        }
    }

    /// Cancels a check in flight and hides the outcome of a finished one.
    private func dropCheck() {
        checkTask?.cancel()
        isChecking = false
        if isCheckNote {
            note = nil
        }
    }
}
