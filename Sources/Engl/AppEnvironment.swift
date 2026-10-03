import EnglCore

/// AppEnvironment wires the app's long-lived dependencies together.
@MainActor
final class AppEnvironment {
    let settings: AppSettings
    let secrets: any SecretStore
    let router: Router
    let keyStore: YandexKeyStore
    let keyCheck: YandexKeyCheck
    let translator: TranslationController
    let pasteboard: SystemPasteboard
    let watcher: ClipboardWatcher

    init() {
        settings = AppSettings()
        secrets = KeychainSecretStore()
        let http = URLSessionHTTPClient()
        router = Router(providers: [
            YandexDictionaryProvider(http: http, secrets: secrets),
            AppleTranslationProvider(),
        ])
        keyStore = YandexKeyStore(secrets: secrets, router: router)
        keyCheck = YandexKeyCheck(http: http)
        translator = TranslationController(router: router)
        pasteboard = SystemPasteboard()
        watcher = ClipboardWatcher(
            pasteboard: pasteboard,
            interval: .seconds(settings.doubleCopyInterval)
        )
    }
}
