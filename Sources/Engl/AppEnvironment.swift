import EnglCore

/// AppEnvironment wires the app's long-lived dependencies together.
@MainActor
final class AppEnvironment {
    let settings: AppSettings
    let secrets: any SecretStore
    let router: Router
    let translator: TranslationController
    let pasteboard: SystemPasteboard
    let watcher: ClipboardWatcher

    init() {
        settings = AppSettings()
        secrets = KeychainSecretStore()
        router = Router(providers: [
            YandexDictionaryProvider(http: URLSessionHTTPClient(), secrets: secrets),
            AppleTranslationProvider(),
        ])
        translator = TranslationController(router: router)
        pasteboard = SystemPasteboard()
        watcher = ClipboardWatcher(
            pasteboard: pasteboard,
            interval: .seconds(settings.doubleCopyInterval)
        )
    }
}
