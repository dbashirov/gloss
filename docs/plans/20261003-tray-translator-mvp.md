# Переводчик в трее macOS (MVP)

## Overview
- Нативное macOS-приложение (Swift, SwiftUI + AppKit), живёт в меню-баре и помогает учить
  английский: быстро переводит слово или предложение en↔ru.
- Вызов: двойной Cmd+C в любом приложении или левый клик по иконке в трее (ручной ввод).
- Для слов показывается словарная карточка: транскрипция, части речи, варианты перевода,
  синонимы, примеры. Для предложений — перевод текста.
- Окно-попап появляется у курсора; кнопкой 📌 его можно закрепить в любом месте экрана.
- MVP работает только на бесплатных источниках (Yandex Dictionary API + Apple Translation),
  но архитектура провайдеров позволяет позже добавить LLM (Claude Haiku 4.5), другие словари
  и OCR без переделки UI.

## Context (from discovery)
- репозиторий пустой (нет ни одного коммита), проект создаётся с нуля
- окружение: macOS 26.6, Swift 6.4, только Command Line Tools (Xcode не установлен)
- ⚠️ CLT повреждены: в `usr/lib/swift/pm/{ManifestAPI/PackageDescription,PluginAPI/PackagePlugin}
  .swiftmodule/` остались `*.private.swiftinterface` от 2024-02-15 (Swift 5.10), из-за них
  любой `Package.swift` с `platforms` не компилируется (`reference to member 'v15' cannot be
  resolved`) — чинится в Task 1
- в SDK есть `Translation` (`TranslationSession(installedSource:target:)`, `LanguageAvailability`),
  `SwiftUI`, `AppKit`, `NaturalLanguage`, `AVFoundation`, `ServiceManagement`
- `NSPasteboard.accessBehavior` (macOS 15.4+): по умолчанию система спрашивает пользователя
  при программном чтении общего буфера; пользователь может выставить «Разрешать всегда»
- языковой пакет en↔ru сейчас не установлен (`LanguageAvailability` → `.supported`)
- Yandex Dictionary API доступен (`dictionary.yandex.net/api/v1/dicservice.json/*`, на невалидный
  ключ — `401 API key is invalid`); бесплатный ключ выдаётся
- Swift 6.4 по умолчанию собирает через Swift Build: путь к бинарникам брать через
  `swift build --show-bin-path`, не хардкодить `.build/release`

## Development Approach
- **testing approach**: Regular (сначала код, затем тесты в той же задаче)
- complete each task fully before moving to the next
- make small, focused changes
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task
  - tests are not optional - they are a required part of the checklist
  - write unit tests for new functions/methods
  - write unit tests for modified functions/methods
  - add new test cases for new code paths
  - update existing test cases if behavior changes
  - tests cover both success and error scenarios
- **CRITICAL: all tests must pass before starting next task** - no exceptions
- **CRITICAL: update this plan file when scope changes during implementation**
- run tests after each change
- код по правилам пользователя: строки ≤120 символов (оптимально 60–90), идиоматично,
  без избыточных комментариев, комментарии внутри функций с маленькой буквы,
  `t` не используется как имя переменной, UUID — `UUIDv7`

## Testing Strategy
- **unit tests**: Swift Testing (`import Testing`), запуск `make test`
- вся тестируемая логика живёт в `EnglCore` (без AppKit/SwiftUI); внешние зависимости
  (HTTP, буфер обмена, часы, Keychain, Apple Translation, UserDefaults) скрыты за протоколами
  и в тестах подменяются фейками
- фикстуры ответов Yandex — JSON-файлы в `Tests/EnglCoreTests/Fixtures/`
- UI (NSPanel, SwiftUI-вьюхи, трей) проверяется по ручному чек-листу из Post-Completion;
  чистые функции UI (позиционирование попапа) выносятся в `EnglCore` и покрываются тестами
- e2e UI-тестов нет

## Progress Tracking
- mark completed items with `[x]` immediately when done
- add newly discovered tasks with ➕ prefix
- document issues/blockers with ⚠️ prefix
- update plan if implementation deviates from original scope
- keep plan in sync with actual work done

## Solution Overview

### Модули
- `EnglCore` (library) — модели, классификатор запроса, `Router`, провайдеры, кеш,
  детектор двойного копирования, `TranslationController`, настройки, геометрия попапа.
  Без AppKit/SwiftUI: всё платформенное — за протоколами.
- `Engl` (executable) — `AppDelegate`, иконка в трее, адаптер `NSPasteboard`, `NSPanel`,
  SwiftUI-вьюхи, окно настроек. Ресурсов в этом target нет (сгенерированный `Bundle.module`
  для executable падает внутри `.app`).

### Ключевые решения
- **Подключаемые провайдеры.** `TranslationProvider` — единственная точка расширения.
  `DictionaryEntry` не зависит от источника: Yandex сейчас, Claude/Free Dictionary позже
  заполняют ту же структуру.
- **Router** определяет язык (en/ru) и тип запроса (слово/фраза ≤3 слов → словарь, иначе
  предложение) и идёт по цепочке провайдеров, переходя к следующему на любую
  `ProviderError`. Если не ответил никто — отдаётся самая полезная ошибка (приоритет ниже).
- **Триггер без перехвата клавиатуры.** Двойной Cmd+C ловится поллингом
  `NSPasteboard.changeCount` (это не требует Accessibility/Input Monitoring). Содержимое
  буфера читается **только после срабатывания** детектора; первое чтение вызовет системный
  запрос доступа к буферу — приложение подсказывает выставить «Разрешать всегда».
- **Безопасность буфера.** Изменения с `org.nspasteboard.ConcealedType` /
  `org.nspasteboard.TransientType` (менеджеры паролей) игнорируются; собственные записи
  в буфер (кнопка 📋) не считаются копированием.
- **Стабильная подпись.** `.app` подписывается локальным self-signed сертификатом
  (`CODESIGN_IDENTITY`): у ad-hoc подписи designated requirement — cdhash, и Keychain
  спрашивает доступ после каждой пересборки. Без переменной — ad-hoc `-`.

### Поток данных
```
ClipboardWatcher (двойной Cmd+C) / ручной ввод в окне
  → TranslationController.translate(text)        # отменяет предыдущий Task
    → TextNormalizer                             # trim, схлопывание пробелов, ≤5000 символов
    → QueryClassifier                            # язык + тип → Query
    → Router (кеш → цепочка провайдеров)
    → RoutedResult(providerID, TranslationResult)
  → state: idle | loading | result | failed
  → PanelController показывает окно, SwiftUI рендерит состояние
```

## Technical Details

### Модели (`EnglCore`)
```swift
enum Language: String, Sendable { case en, ru }
enum QueryKind: Sendable { case dictionary, sentence }

struct Query: Sendable, Hashable {
    let text: String
    let source: Language
    let target: Language
    let kind: QueryKind
}

struct DictionaryEntry: Sendable, Equatable {
    let word: String
    let transcription: String?
    let groups: [PartOfSpeechGroup]
}

struct PartOfSpeechGroup: Sendable, Equatable {
    let partOfSpeech: String?
    let translations: [Sense]
}

struct Sense: Sendable, Equatable {
    let text: String
    let synonyms: [String]
    let meanings: [String]
    let examples: [Example]
}

struct Example: Sendable, Equatable {
    let source: String
    let translation: String?
}

struct TextTranslation: Sendable, Equatable {
    let source: String
    let translation: String
}

enum TranslationResult: Sendable, Equatable {
    case dictionary(DictionaryEntry)
    case text(TextTranslation)
}

struct RoutedResult: Sendable, Equatable {
    let providerID: String
    let result: TranslationResult
}

enum ProviderError: Error, Equatable {
    case notConfigured, notFound, invalidKey, rateLimited, network
    case invalidResponse, languagePackMissing
}

protocol TranslationProvider: Sendable {
    var id: String { get }
    func supports(_ query: Query) -> Bool
    func translate(_ query: Query) async throws -> TranslationResult
}
```

### Классификация запроса
- язык: `NLLanguageRecognizer` с `languageConstraints = [.english, .russian]`; для коротких
  строк (1–2 слова) приоритет у эвристики «есть кириллица → ru, иначе en»
- направление: `en → ru`, `ru → en`
- тип: после нормализации ≤3 слов и нет завершающей пунктуации предложения → `dictionary`,
  иначе `sentence`

### Router и кеш
- `Router` — `actor`, хранит провайдеров по порядку и простой кеш (словарь с лимитом
  500 записей и вытеснением самых старых)
- переходит к следующему провайдеру на **любую** `ProviderError`; `CancellationError`
  пробрасывается сразу
- итоговая ошибка, если не ответил никто, по приоритету:
  `invalidKey` / `rateLimited` / `languagePackMissing` > `network` / `invalidResponse` >
  `notConfigured` > `notFound`
- кешируется только результат, полученный без ошибок предыдущих провайдеров (иначе
  Apple-фолбэк на слово «залипнет» в кеше вместо карточки Yandex); `invalidate()` вызывается
  при смене ключа

### Отмена
- провайдеры маппят `URLError(.cancelled)` и `TranslationError.alreadyCancelled`
  в `CancellationError`, а не в `network`; перед маппингом ошибок —
  `try Task.checkCancellation()`
- `TranslationController` игнорирует `CancellationError` (состояние не меняется)

### Yandex Dictionary API
- `GET https://dictionary.yandex.net/api/v1/dicservice.json/lookup`
- параметры: `key`, `lang` (`en-ru` / `ru-en`), `text`, `ui=ru`, `flags=4` (MORPHO —
  поиск по словоформам: `running` → `run`)
- ответ: `def[]` → `{text, pos, ts, tr[]}`; `tr[]` → `{text, pos, syn[], mean[], ex[]}`;
  `ex[]` → `{text, tr[]}`; ошибка — `{"code": 401, "message": "..."}`
- маппинг: `def` → `PartOfSpeechGroup`, `ts` первого `def` → `transcription`,
  `tr` → `Sense`, `syn[].text` → `synonyms`, `mean[].text` → `meanings`
- ошибки: пустой `def` → `notFound`; 401/402 → `invalidKey`; 403 → `rateLimited`
  (дневной лимит); 413/501 → `notFound`; 5xx и битый JSON → `invalidResponse`;
  таймаут/нет сети → `network`; нет ключа → `notConfigured`
- таймаут запроса 5 с; HTTP скрыт за `protocol HTTPClient: Sendable`

### Apple Translation
- `protocol TextTranslator: Sendable` с асинхронными `status(from:to:)` и
  `translate(_:from:to:)`
- `LanguageAvailability` и `TranslationSession` не `Sendable`: создаются локально внутри
  `async`-методов и не хранятся в свойствах
- статус: `.installed` → переводим, `.supported` → `languagePackMissing`,
  `.unsupported` → `notFound`; `TranslationError.notInstalled` при переводе тоже
  → `languagePackMissing`
- провайдер поддерживает оба типа запроса; для `dictionary` возвращает `.text` (fallback,
  когда Yandex недоступен или не настроен)
- скачивание пакета: из окна настроек через `.translationTask` + `prepareTranslation()`
  (перед этим `NSApp.activate()`, окно должно быть key) + запасной вариант — ссылка
  на «Системные настройки → Основные → Язык и регион → Языки перевода»

### Двойной Cmd+C
- в `EnglCore`: `protocol PasteboardReading { var changeCount: Int { get };
  var types: [String] { get }; func string() -> String? }`; адаптер над
  `NSPasteboard.general` — в `Engl`
- `ClipboardWatcher` (`@MainActor`): цикл
  `Task { @MainActor in while !Task.isCancelled { tick(); try await Task.sleep(...) } }`
  каждые 100 мс (не `Timer` — его замыкание в Swift 6 не изолировано на MainActor);
  при старте запоминает текущий `changeCount` как базу
- `tick()` берёт только `changeCount` и `types`; `string()` вызывается только после
  срабатывания детектора
- `DoubleCopyDetector.register(delta:at:isConcealed:) -> Bool` (чистая логика):
  `delta ≥ 2` за один тик → срабатывание; два изменения в пределах интервала
  (по умолчанию 500 мс, настраивается 300–1000 мс) → срабатывание; после срабатывания
  сброс; Concealed/Transient → сброс
- `ignore(changeCount:)`: собственная запись приложения в буфер не считается копированием
- `accessBehavior == .alwaysDeny` → в окне и в настройках показывается подсказка
  включить доступ в «Конфиденциальность и безопасность → Вставка из других приложений»

### Окно
- `TranslatorPanel: NSPanel`, `styleMask` с `.nonactivatingPanel` задаётся в `init`;
  `canBecomeKey → true`; `level = .floating`;
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`; `hidesOnDeactivate = false`
- показ — `makeKeyAndOrderFront` (панель берёт key-фокус, как Spotlight: можно сразу
  редактировать запрос); Esc — через `cancelOperation(_:)`, не через глобальный монитор
- контент: фиксированная ширина (~380 pt), максимальная высота (~480 pt) со скроллом;
  при изменении размера контента origin пересчитывается через `PopupGeometry`
- попап: origin — `PopupGeometry.origin(cursor:size:visibleFrame:)` (смещение от курсора,
  clamp к экрану, переворот вверх/влево у краёв)
- закрытие попапа: Esc, глобальный монитор `leftMouseDown`/`rightMouseDown` вне окна,
  `NSWorkspace.didActivateApplicationNotification`; монитор снимается при скрытии
- 📌: мониторы отключаются, перетаскивание — через ручку в заголовке (`WindowDragGesture`),
  т.к. `isMovableByWindowBackground` поверх `NSHostingView` не работает; позиция сохраняется
  при `windowDidMove`; сохранённая позиция при показе прогоняется через clamp (монитор
  мог быть отключён)

### Трей
- `NSStatusItem` без `statusItem.menu`; `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`:
  левый клик — панель ручного ввода, правый — меню («Двойной Cmd+C ✓», «Настройки…», «Выход»)

### Настройки (`UserDefaults`)
- `AppSettings` (`@Observable`): хранимые свойства с `didSet → defaults.set`, загрузка в `init`
  (вычисляемые свойства поверх `UserDefaults` не уведомляют SwiftUI)
- `doubleCopyEnabled: Bool = true`, `doubleCopyInterval: Double = 0.5`,
  `isPinned: Bool = false`, `pinnedOrigin: CGPoint?` (хранится как два `Double`)
- ключ Yandex — в Keychain (`service = com.dbashirov.engl`, `account = yandex-dictionary`)
- запуск при логине — состояние из `SMAppService.mainApp.status`; работает только для
  бандла из `/Applications`; `.requiresApproval` → `SMAppService.openSystemSettingsLoginItems()`

### Сборка
- `Package.swift`: `// swift-tools-version:6.2`, `platforms: [.macOS(.v26)]`, targets
  `EnglCore`, `Engl`, `EnglCoreTests` (ресурсы-фикстуры через `.process("Fixtures")`)
- `scripts/build-app.sh`: `swift build -c release`, `BIN=$(swift build -c release --show-bin-path)`
  → `build/Engl.app/Contents/{MacOS,Resources}` + `Info.plist` →
  `codesign --force --sign "${CODESIGN_IDENTITY:--}" build/Engl.app`
- `Info.plist`: `CFBundleIdentifier = com.dbashirov.engl`, `CFBundleExecutable = Engl`,
  `CFBundleName = Engl`, `CFBundlePackageType = APPL`, `CFBundleShortVersionString = 0.1.0`,
  `CFBundleVersion = 1`, `LSUIElement = true`, `LSMinimumSystemVersion = 26.0`
- `Makefile`: `build`, `test`, `app`, `run` (`open build/Engl.app`), `install`
  (копия в `/Applications`), `clean`

## What Goes Where
- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates
- **Post-Completion** (no checkboxes): items requiring external action - manual testing, changes in consuming projects, deployment configs, third-party verifications

## Implementation Steps

### Task 1: Починка тулчейна и каркас пакета

**Files:**
- Create: `Package.swift`
- Create: `Sources/EnglCore/EnglCore.swift`
- Create: `Sources/Engl/main.swift`
- Create: `Tests/EnglCoreTests/SmokeTests.swift`
- Create: `Makefile`
- Create: `.gitignore`

- [x] починить CLT (выполнил пользователь): удалены устаревшие
  `/Library/Developer/CommandLineTools/usr/lib/swift/pm/{ManifestAPI/PackageDescription,
  PluginAPI/PackagePlugin}.swiftmodule/*.private.swiftinterface`; `swift build` работает
- [x] создать `Package.swift` с targets `EnglCore`, `Engl`, `EnglCoreTests`, платформа macOS 26
- [x] минимальный `Sources/Engl/main.swift` (запускает `NSApplication`, пока без UI)
- [x] `.gitignore` (`.build/`, `build/`, `.swiftpm/`, `*.xcodeproj`)
- [x] `Makefile` с целями `build`, `test`, `clean`; ⚠️ на CLT без Xcode `swift test` не находит
  плагин макросов Swift Testing (`plugin for module 'TestingMacros' not found`) — цель `test`
  передаёт `-Xswiftc -plugin-path -Xswiftc <toolchain>/usr/lib/swift/host/plugins/testing`,
  где `<toolchain>` вычисляется из `xcrun --find swift` (проверено: с флагом тесты проходят);
  тесты запускать только через `make test`
- [x] написать smoke-тест в `SmokeTests.swift`
- [x] run tests (`make test`) - must pass before next task

### Task 2: Модели и нормализация текста

**Files:**
- Create: `Sources/EnglCore/Models.swift`
- Create: `Sources/EnglCore/ProviderError.swift`
- Create: `Sources/EnglCore/TextNormalizer.swift`
- Create: `Tests/EnglCoreTests/TextNormalizerTests.swift`
- Delete: `Sources/EnglCore/EnglCore.swift`, `Tests/EnglCoreTests/SmokeTests.swift`

- [x] описать модели из Technical Details и `ProviderError`
- [x] реализовать `TextNormalizer.normalize(_:) -> String?`: trim, схлопывание пробелов
  и переводов строк, обрезка до 5000 символов, `nil` для пустой строки
- [x] написать тесты нормализации (обычный текст, многострочный, пробелы/табы)
- [x] написать тесты граничных случаев (пустая строка, только пробелы, >5000 символов)
- [x] run tests - must pass before next task

### Task 3: Классификатор запроса (язык и тип)

**Files:**
- Create: `Sources/EnglCore/QueryClassifier.swift`
- Create: `Tests/EnglCoreTests/QueryClassifierTests.swift`

- [x] реализовать определение языка: эвристика по кириллице для коротких строк,
  `NLLanguageRecognizer` с ограничением en/ru для длинных
- [x] реализовать определение типа: ≤3 слов без завершающей пунктуации → `dictionary`
- [x] собрать `QueryClassifier.classify(_:) -> Query` с направлением en→ru / ru→en
- [x] написать тесты: английское слово, русское слово, фраза из 3 слов, предложение en/ru
- [x] написать тесты пограничных случаев: слово с апострофом (`don't`), дефис
  (`well-known`), смешанный текст, цифры, «Hello.» с точкой
- [x] run tests - must pass before next task

### Task 4: Протокол провайдера и Router с кешем

**Files:**
- Create: `Sources/EnglCore/TranslationProvider.swift`
- Create: `Sources/EnglCore/Router.swift`
- Create: `Tests/EnglCoreTests/RouterTests.swift`
- Create: `Tests/EnglCoreTests/Fakes/FakeProvider.swift`

- [x] объявить `protocol TranslationProvider`
- [x] реализовать `actor Router` с `route(_:) async throws -> RoutedResult` и `invalidate()`:
  кеш с лимитом, цепочка провайдеров, переход дальше на любую `ProviderError`,
  приоритет итоговой ошибки, кеширование только «чистых» результатов (см. Technical Details)
- [x] написать тесты: первый провайдер ответил; `notFound` → второй; `invalidKey` → второй
  ответил; провайдер не поддерживает запрос; все упали → ошибка по приоритету
- [x] написать тесты кеша и отмены: повторный запрос из кеша; результат фолбэка не кешируется;
  `invalidate()` очищает кеш; вытеснение при превышении лимита; `CancellationError`
  не приводит к переходу на следующий провайдер
- [x] run tests - must pass before next task

### Task 5: Хранилище секретов (Keychain)

**Files:**
- Create: `Sources/EnglCore/SecretStore.swift`
- Create: `Sources/EnglCore/KeychainSecretStore.swift`
- Create: `Tests/EnglCoreTests/KeychainSecretStoreTests.swift`
- Create: `Tests/EnglCoreTests/InMemorySecretStoreTests.swift`
- Create: `Tests/EnglCoreTests/Helpers/UUIDv7.swift`, `Tests/EnglCoreTests/UUIDv7Tests.swift`

- [x] `protocol SecretStore: Sendable { func read(_ account: String) throws -> String?;
  func write(_ value: String?, account: String) throws }`
- [x] `KeychainSecretStore` на `SecItemCopyMatching`/`SecItemAdd`/`SecItemUpdate`/`SecItemDelete`
  с понятной ошибкой по `OSStatus`
- [x] `InMemorySecretStore` (`Sendable` через `Mutex` из `Synchronization`) для тестов и превью
- [x] написать тесты round-trip для Keychain с уникальным `service` на прогон
  (`com.dbashirov.engl.tests.<UUIDv7>`) и удалением в `defer`: запись, чтение, обновление,
  удаление, чтение отсутствующего
- [x] написать тесты `InMemorySecretStore`
- [x] run tests - must pass before next task

### Task 6: HTTP-клиент и YandexDictionaryProvider

**Files:**
- Create: `Sources/EnglCore/HTTPClient.swift`
- Create: `Sources/EnglCore/Providers/YandexDictionaryProvider.swift`
- Create: `Sources/EnglCore/Providers/YandexDTO.swift`
- Create: `Tests/EnglCoreTests/YandexDictionaryProviderTests.swift`
- Create: `Tests/EnglCoreTests/Fakes/FakeHTTPClient.swift`
- Create: `Tests/EnglCoreTests/Fixtures/yandex_run.json`
- Create: `Tests/EnglCoreTests/Fixtures/yandex_empty.json`
- Create: `Tests/EnglCoreTests/Fixtures/yandex_ru_word.json`
- Create: `Tests/EnglCoreTests/Fixtures/yandex_error_401.json`
- Modify: `Package.swift` (ресурсы тестов)

- [x] `protocol HTTPClient: Sendable` + реализация на `URLSession` с таймаутом 5 с
- [x] DTO ответа `lookup` и маппинг в `DictionaryEntry`
- [x] провайдер: `supports` только для `kind == .dictionary`, ключ из `SecretStore`,
  построение URL с `lang`, `ui=ru`, `flags=4`
- [x] маппинг HTTP-статусов, битого JSON и сетевых ошибок в `ProviderError`;
  `URLError(.cancelled)` → `CancellationError`
- [x] фикстуры написать вручную по документации (`def/ts/tr/syn/mean/ex`); когда появится
  ключ — сверить с реальным ответом `curl`
  (сверка с реальным ответом пропущена — ключа нет; ⚠️ сделать при появлении ключа)
- [x] написать тесты парсинга фикстур (части речи, транскрипция, синонимы, примеры)
- [x] написать тесты ошибок: нет ключа, пустой `def`, 401, 402, 403, 413, 500, битый JSON,
  таймаут, отмена
- [x] написать тест построения URL (параметры, экранирование текста)
- [x] run tests - must pass before next task

### Task 7: AppleTranslationProvider

**Files:**
- Create: `Sources/EnglCore/Providers/AppleTranslationProvider.swift`
- Create: `Sources/EnglCore/Providers/TextTranslator.swift`
- Create: `Tests/EnglCoreTests/AppleTranslationProviderTests.swift`
- Create: `Tests/EnglCoreTests/Fakes/FakeTextTranslator.swift`

- [x] `protocol TextTranslator: Sendable` (async статус + перевод) и реализация на
  `Translation` с локальным созданием `LanguageAvailability`/`TranslationSession`
- [x] провайдер: поддерживает оба типа, возвращает `.text`, маппит статус и
  `TranslationError.notInstalled` в `languagePackMissing`, `.unsupported` в `notFound`,
  отмену в `CancellationError`
- [x] написать тесты провайдера на фейке: установлен, не скачан, не поддерживается,
  `notInstalled` при переводе, прочая ошибка перевода, отмена
- [x] написать интеграционный тест на реальном `Translation` с
  `.enabled(if:)` по статусу `.installed` (сейчас будет пропущен)
  (на этой машине пакет en↔ru не установлен — suite пропускается по runtime-условию)
- [x] run tests - must pass before next task

### Task 8: Детектор двойного Cmd+C и ClipboardWatcher

**Files:**
- Create: `Sources/EnglCore/Clipboard/DoubleCopyDetector.swift`
- Create: `Sources/EnglCore/Clipboard/ClipboardWatcher.swift`
- Create: `Sources/EnglCore/Clipboard/PasteboardReading.swift`
- Create: `Tests/EnglCoreTests/DoubleCopyDetectorTests.swift`
- Create: `Tests/EnglCoreTests/ClipboardWatcherTests.swift`
- Create: `Tests/EnglCoreTests/Fakes/FakePasteboard.swift`

- [x] `DoubleCopyDetector.register(delta:at:isConcealed:) -> Bool` — чистая логика
- [x] протокол `PasteboardReading` (только протокол, адаптер — в Task 10)
- [x] `ClipboardWatcher` (`@MainActor`): цикл на `Task.sleep` 100 мс, `start`/`stop`,
  базовый `changeCount` при старте, интервал из настроек, `ignore(changeCount:)`,
  чтение `string()` только после срабатывания, колбэк `onDoubleCopy(String)`
- [x] написать тесты детектора: два изменения в окне → триггер; вне окна → нет;
  `delta = 2` за один тик → триггер; третье изменение не даёт второй триггер;
  Concealed/Transient сбрасывает
- [x] написать тесты watcher на `FakePasteboard` и ручном `tick()`: стартовый `changeCount`
  не считается копированием; текст доходит до колбэка; `string()` не вызывается до
  срабатывания; нетекстовый буфер игнорируется; собственная запись игнорируется;
  после `stop` колбэк не вызывается
- [x] run tests - must pass before next task

### Task 9: Настройки и TranslationController

**Files:**
- Create: `Sources/EnglCore/AppSettings.swift`
- Create: `Sources/EnglCore/TranslationController.swift`
- Create: `Tests/EnglCoreTests/AppSettingsTests.swift`
- Create: `Tests/EnglCoreTests/TranslationControllerTests.swift`

- [x] `AppSettings` (`@Observable`, хранимые свойства + `didSet`, инжектируемый
  `UserDefaults` suite): `doubleCopyEnabled`, `doubleCopyInterval`, `isPinned`, `pinnedOrigin`
- [x] `TranslationController` (`@MainActor`, `@Observable`): `state` (`idle`, `loading(query)`,
  `result(RoutedResult)`, `failed(text, ProviderError)`), `translate(_:)` с нормализацией,
  классификацией и отменой предыдущего `Task`; `CancellationError` не меняет состояние
- [x] написать тесты настроек: значения по умолчанию, сохранение и повторная загрузка
  из того же suite, `pinnedOrigin` = `nil` и заданный
- [x] написать тесты контроллера: успешный перевод, ошибка, пустой ввод не меняет состояние,
  второй запрос отменяет первый (результат первого не попадает в `state`)
- [x] run tests - must pass before next task

### Task 10: Оболочка приложения, трей и сборка .app

Перед ручной проверкой: установить пакет en↔ru через «Системные настройки → Основные →
Язык и регион → Языки перевода» и/или ввести ключ Yandex (временно через `security
add-generic-password` до появления окна настроек в Task 13).

**Files:**
- Modify: `Sources/Engl/main.swift`
- Create: `Sources/Engl/AppDelegate.swift`
- Create: `Sources/Engl/StatusItemController.swift`
- Create: `Sources/Engl/AppEnvironment.swift`
- Create: `Sources/Engl/SystemPasteboard.swift`
- Create: `Resources/Info.plist`
- Create: `scripts/build-app.sh`
- Modify: `Makefile`

- [x] `SystemPasteboard`: адаптер `PasteboardReading` над `NSPasteboard.general`
  + `accessBehavior`
- [x] `AppEnvironment`: сборка зависимостей (Keychain, провайдеры Yandex → Apple, Router,
  `TranslationController`, `ClipboardWatcher`, `AppSettings`)
- [x] `AppDelegate`: `.accessory` activation policy, запуск watcher по настройке,
  связка `onDoubleCopy` → `TranslationController.translate`
- [x] `StatusItemController`: иконка (SF Symbol `character.book.closed`), левый клик →
  окно ручного ввода (пока лог), правый клик → меню «Двойной Cmd+C ✓», «Настройки…», «Выход»
- [x] `Info.plist` с полным набором ключей, `scripts/build-app.sh` (`--show-bin-path`,
  упаковка, `codesign` с `CODESIGN_IDENTITY` или ad-hoc), цели `app`, `run`, `install`
- [x] проверить вручную: `make run` → иконка в трее, нет иконки в Dock, при первом двойном
  Cmd+C — системный запрос доступа к буферу, после разрешения результат перевода в логе
  (skipped - not automatable, needs user; автоматически проверено: структура бандла,
  `codesign --verify --strict`, `plutil -lint`, `open build/Engl.app` → процесс запущен,
  затем остановлен)
- [x] тесты: новой логики в `EnglCore` нет; убедиться, что все тесты проходят (`make test`)
- [x] run tests - must pass before next task

### Task 11: Плавающая панель: попап и закрепление

**Files:**
- Create: `Sources/EnglCore/PopupGeometry.swift`
- Create: `Tests/EnglCoreTests/PopupGeometryTests.swift`
- Create: `Sources/Engl/Panel/TranslatorPanel.swift`
- Create: `Sources/Engl/Panel/PanelController.swift`
- Modify: `Sources/Engl/AppDelegate.swift`
- Modify: `Sources/Engl/StatusItemController.swift` (не потребовалось: колбэк уже был)
- ➕ Create: `Sources/Engl/Panel/PanelHostingView.swift` (сигнал об изменении размера контента)
- ➕ Create: `Sources/Engl/Panel/PanelPlaceholderView.swift` (временный контент до Task 12)

- [x] `PopupGeometry.origin(cursor:size:visibleFrame:)` и `clamp(origin:size:visibleFrame:)`
- [x] `TranslatorPanel`: конфигурация из Technical Details, `canBecomeKey`, Esc через
  `cancelOperation(_:)` в режиме попапа
- [x] `PanelController`: показ попапа у курсора / в закреплённой позиции (с clamp),
  `makeKeyAndOrderFront`, глобальный монитор клика вне окна и
  `didActivateApplicationNotification` (только в попапе, снимаются при скрытии),
  переключение 📌, сохранение позиции при `windowDidMove`, пересчёт origin
  при изменении размера контента
- [x] подключить: двойной Cmd+C → показ панели, левый клик по иконке → показ с пустым полем
- [x] написать тесты `PopupGeometry`: центр экрана, правый край, нижний край, второй
  монитор со смещённым `visibleFrame`, окно больше экрана, закреплённая позиция
  за пределами текущих экранов
- [x] run tests - must pass before next task

### Task 12: SwiftUI-содержимое окна

**Files:**
- Create: `Sources/Engl/Views/TranslatorView.swift`
- Create: `Sources/Engl/Views/DictionaryCardView.swift`
- Create: `Sources/Engl/Views/TextResultView.swift`
- Create: `Sources/Engl/Views/HeaderView.swift`
- Create: `Sources/Engl/Views/FooterView.swift`
- Create: `Sources/Engl/Speech.swift`
- Create: `Sources/EnglCore/ProviderError+Message.swift`
- Create: `Tests/EnglCoreTests/ProviderErrorMessageTests.swift`
- ➕ Create: `Sources/EnglCore/ResultPresentation.swift` (имя источника, текст для 📋, код голоса)
- ➕ Create: `Sources/Engl/Panel/PanelModel.swift` (`PanelModel` + `PanelActions`)
- ➕ Create: `Sources/Engl/SystemSettingsLink.swift` (панели «Системных настроек» для действий ошибок)
- ➕ Modify: `Sources/Engl/Panel/PanelController.swift`, `Sources/Engl/AppDelegate.swift`,
  `Sources/Engl/SystemPasteboard.swift`, `Sources/EnglCore/ProviderError.swift` (`CaseIterable`)
- ➕ Delete: `Sources/Engl/Panel/PanelPlaceholderView.swift`

- [x] `HeaderView`: ручка перетаскивания (`WindowDragGesture`) и 📌
- [x] ➕ кнопка ✕ в `HeaderView` закрывает панель в любом режиме; Esc снова закрывает
  только попап (закреплённое окно — только по ✕)
- [x] `TranslatorView`: поле запроса (Enter → `translate`), переключение по `state`:
  загрузка, карточка, текст, ошибка с действием; фиксированная ширина, максимальная
  высота со скроллом
- [x] `DictionaryCardView`: слово + транскрипция + 🔊, группы по частям речи, варианты,
  синонимы, примеры с переводом
- [x] `TextResultView`: перевод с выделяемым текстом
- [x] `FooterView`: источник (по `providerID`), 📋 копировать перевод (запись с
  `TransientType`, `changeCount` записи передаётся в `ClipboardWatcher.ignore`)
- [x] `Speech`: `AVSpeechSynthesizer` с голосом под язык
- [x] `ProviderError` → русский текст и тип действия (открыть настройки / скачать пакет /
  разрешить доступ к буферу); до Task 13 «открыть настройки» пишет в лог, «скачать пакет»
  и «разрешить доступ» открывают нужные панели «Системных настроек»
- [x] написать тесты сообщений об ошибках (каждый case имеет текст и правильное действие)
- [x] run tests - must pass before next task

### Task 13: Окно настроек

**Files:**
- Create: `Sources/Engl/Settings/SettingsView.swift`
- Create: `Sources/Engl/Settings/SettingsWindowController.swift`
- Create: `Sources/Engl/Settings/LanguagePackView.swift`
- Create: `Sources/EnglCore/YandexKeyCheck.swift`
- Create: `Tests/EnglCoreTests/YandexKeyCheckTests.swift`

- [ ] раздел «Основные»: запуск при входе (`SMAppService.mainApp`, только из `/Applications`,
  `.requiresApproval` → `openSystemSettingsLoginItems()`), двойной Cmd+C вкл/выкл и интервал
  (слайдер 300–1000 мс), статус доступа к буферу (`accessBehavior`) с подсказкой
- [ ] раздел «Словари»: поле ключа Yandex (`SecureField`), сохранение в Keychain +
  `Router.invalidate()`, кнопка «Проверить» — `YandexKeyCheck`: lookup `hello` через
  `YandexDictionaryProvider` с временным `InMemorySecretStore` (без нового HTTP-кода),
  ссылка на получение ключа
- [ ] `LanguagePackView`: статус пакета en↔ru, кнопка «Скачать» (`NSApp.activate()` +
  `.translationTask` + `prepareTranslation()`), ссылка на системные настройки как запасной путь
- [ ] открытие окна из меню трея и из действия ошибки в панели
- [ ] написать тесты `YandexKeyCheck` на `FakeHTTPClient`: валидный ключ, 401,
  нет сети, пустой ключ
- [ ] run tests - must pass before next task

### Task 14: Verify acceptance criteria
- [ ] verify all requirements from Overview are implemented
- [ ] verify edge cases are handled (пароль из менеджера паролей, пустой буфер, картинка
  в буфере, очень длинный текст, нет сети, нет ключа, нет языкового пакета, доступ
  к буферу запрещён)
- [ ] run full test suite: `make test`
- [ ] собрать и запустить `.app`: `make app && make run`
- [ ] verify test coverage meets project standard (`swift test --enable-code-coverage`,
  `EnglCore` ≥ 80%)

### Task 15: [Final] Update documentation
- [ ] создать `README.md`: что это, сборка (`make app`, `make install`), получение ключа
  Yandex, создание self-signed сертификата подписи и `CODESIGN_IDENTITY` (и почему без него
  Keychain спрашивает доступ после каждой пересборки), доступ к буферу обмена, использование
- [ ] создать `CLAUDE.md` с командами сборки/тестов и правилами проекта
  (EnglCore без UI, новые источники — через `TranslationProvider`)
- [ ] move this plan to `docs/plans/completed/`

## Post-Completion
*Items requiring manual intervention or external systems - no checkboxes, informational only*

**Ручная подготовка:**
- починить Command Line Tools (Task 1) — нужен `sudo`
- получить бесплатный ключ Yandex Dictionary API и ввести его в настройках
- один раз создать self-signed сертификат подписи кода (Связка ключей → Ассистент
  сертификации → «Создать сертификат», тип «Подписание кода») и экспортировать
  `CODESIGN_IDENTITY`
- скачать языковой пакет en↔ru
- при первом двойном Cmd+C разрешить доступ к буферу («Разрешать всегда»)

**Ручная проверка UI:**
- двойной Cmd+C в Safari, Chrome, VS Code, Terminal, Telegram, Preview (PDF), Notes —
  в каких приложениях повторный Cmd+C не меняет `changeCount` (если таких много —
  рассмотреть `CGEventTap`)
- ложные срабатывания: приложения, где одно копирование даёт два изменения `changeCount`
  (менеджеры буфера, некоторые Electron-приложения)
- копирование пароля из менеджера паролей не вызывает перевод
- доступ к буферу: режимы «Спрашивать» / «Разрешать всегда» / «Запрещать»
- попап у курсора: края экрана, второй монитор, полноэкранное приложение, другой Space
- закреплённое окно: перетаскивание за ручку, позиция переживает перезапуск и отключение
  монитора, новые переводы появляются в нём
- Esc, клик мимо и Cmd+Tab закрывают попап, но не закреплённое окно
- 🔊 произносит слово, 📋 копирует и не запускает повторный перевод
- поведение без сети (Yandex → fallback на Apple), без ключа, без языкового пакета
- запуск при входе в систему после перезагрузки (бандл из `/Applications`)

**Future (следующие этапы, вне MVP):**
- `ClaudeProvider`: Claude Haiku 4.5 по умолчанию (модель в настройках), raw HTTP
  к `POST /v1/messages`, structured JSON output → `DictionaryEntry`; кнопка «Разобрать»
  для предложений (грамматика, идиомы)
- постоянный кеш в SQLite + история запросов + «мой словарь» и карточки для повторения
- `FreeDictionaryProvider` (dictionaryapi.dev): английские определения, IPA, аудио
- OCR: выделение области экрана (ScreenCaptureKit) + распознавание текста (Vision)
- глобальный хоткей и опционально `CGEventTap` для более надёжного двойного Cmd+C
