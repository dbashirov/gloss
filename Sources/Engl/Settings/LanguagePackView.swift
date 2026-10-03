import EnglCore
import SwiftUI
import Translation

/// LanguagePackView shows whether the en↔ru pack is installed and downloads it
/// with the system dialog; System Settings are the fallback.
struct LanguagePackView: View {
    let model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            status
            HStack {
                if model.packState == .notInstalled {
                    Button("Скачать") {
                        model.downloadPack()
                    }
                    .disabled(model.packDownload.isActive)
                }
                if model.packDownload.isActive {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Открыть «Языки перевода»") {
                    SystemSettingsLink.translationLanguages.open()
                }
                .buttonStyle(.link)
            }
            SettingsNoteView(note: model.packNote)
        }
        .translationTask(
            model.packDownload.configuration,
            action: prepare(requestID: model.packDownload.requestID)
        )
    }

    // nonisolated: the session is not Sendable and must stay off the main actor
    private nonisolated func prepare(
        requestID: Int
    ) -> @Sendable (TranslationSession) async -> Void {
        { [model] session in
            let failure: String?
            do {
                try await session.prepareTranslation()
                failure = nil
            } catch is CancellationError {
                failure = nil
            } catch {
                failure = error.localizedDescription
            }
            await model.packDownloadFinished(requestID: requestID, failure: failure)
        }
    }

    @ViewBuilder
    private var status: some View {
        if let state = model.packState {
            Label(
                state.message,
                systemImage: state == .installed ? "checkmark.circle" : "exclamationmark.triangle"
            )
        } else {
            LoadingLabel("Проверяю…")
        }
    }
}
