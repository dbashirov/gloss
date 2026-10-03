import Foundation
import Observation
import os

/// SettingsNote is a one-line outcome shown under a settings control.
public struct SettingsNote: Equatable, Sendable {
    public let text: String
    public let isError: Bool

    public static func success(_ text: String) -> SettingsNote {
        SettingsNote(text: text, isError: false)
    }

    public static func failure(_ text: String) -> SettingsNote {
        SettingsNote(text: text, isError: true)
    }
}

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
        subsystem: "com.dbashirov.engl",
        category: "settings"
    )
    @ObservationIgnored private(set) var checkTask: Task<Void, Never>?
    @ObservationIgnored private(set) var saveTask: Task<Void, Never>?

    public init(store: YandexKeyStore, keyCheck: YandexKeyCheck) {
        self.store = store
        self.keyCheck = keyCheck
    }

    public var canSave: Bool {
        isLoaded || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Reads the stored key into the draft and drops the state of the previous visit.
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
    }

    public func save() {
        guard canSave else {
            return
        }
        let key = draft
        // saves run one after another, so the last one pressed is the one stored
        let previous = saveTask
        saveTask = Task {
            await previous?.value
            do {
                try await store.save(key)
            } catch {
                let reason = error.localizedDescription
                logger.error("saving the key failed: \(reason, privacy: .public)")
                note = .failure("Не удалось сохранить ключ в Связку ключей")
                return
            }
            let saved = key.trimmingCharacters(in: .whitespacesAndNewlines)
            isLoaded = true
            // the user may have edited the field while the key was being saved
            if draft == key {
                draft = saved
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
            } catch let error as ProviderError {
                outcome = .failure(error.message)
            } catch {
                // includes a CancellationError of a check nobody cancelled
                outcome = .failure(ProviderError.invalidResponse.message)
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
