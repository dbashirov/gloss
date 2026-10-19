import GlossCore

/// AppEnvironment wires the app's long-lived dependencies together.
@MainActor
final class AppEnvironment {
    let settings: AppSettings
    let keyStore: YandexKeyStore
    let keyCheck: YandexKeyCheck
    let translator: TranslationController
    let pasteboard: SystemPasteboard
    let watcher: ClipboardWatcher
    let screenCapture: SystemScreenCapture
    let screenText: ScreenTextReader

    init() {
        settings = AppSettings()
        let secrets = CachedSecretStore(KeychainSecretStore())
        let http = URLSessionHTTPClient()
        let router = Router(providers: [
            YandexDictionaryProvider(http: http, secrets: secrets),
            AppleTranslationProvider(),
        ])
        keyStore = YandexKeyStore(secrets: secrets, router: router)
        keyCheck = YandexKeyCheck(http: http)
        translator = TranslationController(router: router)
        pasteboard = SystemPasteboard()
        // the interval comes from settings in AppDelegate.applyDoubleCopySettings
        watcher = ClipboardWatcher(pasteboard: pasteboard)
        screenCapture = SystemScreenCapture()
        screenText = ScreenTextReader(capture: screenCapture, recognizer: VisionTextRecognizer())
    }
}
