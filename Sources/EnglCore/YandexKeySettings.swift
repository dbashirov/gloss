import Foundation
import Observation
import os

/// YandexKeySettings is the state of the API key field in the settings window:
/// the draft, the outcome of the last save or check and the check in progress.
@MainActor
@Observable
public final class YandexKeySettings {
    public var draft = ""
    public private(set) var note: SettingsNote?
    public private(set) var isChecking = false
    /// `false` after a failed read: the key may still be stored, so an empty draft
    /// must not delete it.
    public private(set) var isLoaded = false

    @ObservationIgnored private let store: YandexKeyStore
    @ObservationIgnored private let keyCheck: YandexKeyCheck
    @ObservationIgnored private let logger = Logger(
        subsystem: AppIdentity.bundleID,
        category: "settings"
    )
    @ObservationIgnored private(set) var checkTask: Task<Void, Never>?
    @ObservationIgnored private(set) var saveTask: Task<Void, Never>?
    /// The draft as `load()` or a finished save set it; `nil` from the start of a save,
    /// so what the user typed is never replaced.
    @ObservationIgnored private var syncedDraft: String?

    public init(store: YandexKeyStore, keyCheck: YandexKeyCheck) {
        self.store = store
        self.keyCheck = keyCheck
    }

    public var canSave: Bool {
        isLoaded || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Reads the stored key into the draft and drops the state of the previous visit.
    /// A save still in flight replaces the value read here when it finishes.
    public func load() {
        checkTask?.cancel()
        isChecking = false
        note = nil
        do {
            draft = try store.load()
            isLoaded = true
        } catch {
            let reason = error.localizedDescription
            logger.error("reading the key failed: \(reason, privacy: .public)")
            draft = ""
            isLoaded = false
            note = .failure("Не удалось прочитать ключ из Связки ключей")
        }
        syncedDraft = draft
    }

    public func save() {
        guard canSave else {
            return
        }
        let key = draft
        syncedDraft = nil
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
            isLoaded = true
            // keep what the user typed meanwhile, but not a value read before the save ended
            if draft == key || draft == syncedDraft {
                draft = saved
                syncedDraft = saved
            }
            note = .success(saved.isEmpty ? "Ключ удалён" : "Ключ сохранён")
        }
    }

    /// Checks the draft with a real request without saving it.
    public func check() {
        checkTask?.cancel()
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
            // a newer check or a reload has taken over
            guard !Task.isCancelled else {
                return
            }
            note = outcome
            isChecking = false
        }
    }
}
