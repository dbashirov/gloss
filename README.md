# Engl

Переводчик en↔ru в меню-баре macOS для изучения английского. Двойной Cmd+C в любом
приложении — и рядом с курсором появляется окно с переводом:

- для слова или короткой фразы (до 3 слов) — словарная карточка: транскрипция,
  части речи, варианты перевода, синонимы, примеры;
- для предложения — перевод текста.

Источники бесплатные: Yandex Dictionary API (словарь) и Apple Translation (перевод
предложений и запасной вариант, когда Yandex недоступен или не настроен).

## Требования

- macOS 26;
- Command Line Tools (Xcode не нужен): `xcode-select --install`.

### Особенности Command Line Tools

- **Устаревшие `*.private.swiftinterface`.** В некоторых установках CLT остаются файлы
  от Swift 5.10, из-за которых любой `Package.swift` с `platforms` не собирается
  (`reference to member 'v15' cannot be resolved`). Лечится удалением:
  ```sh
  sudo rm /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface \
          /Library/Developer/CommandLineTools/usr/lib/swift/pm/PluginAPI/PackagePlugin.swiftmodule/*.private.swiftinterface
  ```
- **Swift Testing.** Без Xcode `swift test` не находит плагин макросов
  (`plugin for module 'TestingMacros' not found`). `make test` и `make coverage` сами
  передают `-plugin-path` к `<toolchain>/usr/lib/swift/host/plugins/testing`, поэтому
  тесты запускаются только через `make`.
- **Нет плагина `SwiftUIMacros`.** Макрос `@State` недоступен, поэтому состояние вьюх
  объявляется как `private let x = State(initialValue: ...)` с доступом через
  `x.wrappedValue`. `@FocusState` и `@Bindable` работают как обычно.

## Сборка и запуск

| Команда         | Что делает                                                       |
|-----------------|------------------------------------------------------------------|
| `make build`    | debug-сборка пакета                                              |
| `make test`     | unit-тесты (Swift Testing)                                       |
| `make coverage` | тесты с покрытием и отчёт `llvm-cov` по `Sources/EnglCore`       |
| `make app`      | release-сборка и упаковка в `build/Engl.app` с подписью          |
| `make run`      | `make app` + запуск `build/Engl.app`                             |
| `make install`  | `make app` + копия в `/Applications/Engl.app`                    |
| `make clean`    | очистка `.build` и `build`                                       |

Приложение живёт только в меню-баре (иконка книги), в Dock его нет.

## Первичная настройка

### Ключ Yandex Dictionary

1. Войти с Яндекс ID и получить бесплатный ключ:
   <https://yandex.ru/dev/dictionary/keys/get/?service=dict>.
2. Правый клик по иконке в трее → «Настройки…» → раздел «Словари».
3. Вставить ключ, нажать «Сохранить», затем «Проверить».

Ключ хранится в Keychain (`service = com.dbashirov.engl`, `account = yandex-dictionary`).
Без ключа слова переводятся через Apple Translation — без словарной карточки.

### Подпись кода (`CODESIGN_IDENTITY`)

Без переменной `.app` подписывается ad-hoc. У такой подписи designated requirement —
хеш бинарника, поэтому после каждой пересборки Keychain считает приложение новым
и снова спрашивает доступ к ключу. Стабильный self-signed сертификат это решает:

1. «Связка ключей» → меню «Связка ключей» → «Ассистент сертификации» →
   «Создать сертификат…».
2. Имя, например `Engl Local Signing`; тип удостоверения — «Самоподписанный корневой»;
   тип сертификата — «Подписание кода».
3. Проверить, что сертификат виден: `security find-identity -p codesigning`.
4. Экспортировать переменную (например, в `~/.zshrc`):
   ```sh
   export CODESIGN_IDENTITY="Engl Local Signing"
   ```
5. `make app`. При первой подписи `codesign` может запросить доступ к закрытому ключу —
   «Разрешать всегда». После смены подписи Keychain один раз спросит доступ к ключу
   Yandex — тоже «Разрешать всегда».

### Доступ к буферу обмена

macOS спрашивает разрешение, когда приложение читает чужой буфер. При первом двойном
Cmd+C выберите «Разрешать всегда». Если доступ запрещён, окно покажет подсказку;
включить его можно в «Системные настройки → Конфиденциальность и безопасность →
Вставка из других приложений» (кнопка есть и в настройках Engl).

### Языковой пакет en↔ru

Нужен Apple Translation. Настройки Engl → «Языковой пакет» → «Скачать» или
«Системные настройки → Основные → Язык и регион → Языки перевода» (английский и русский).

## Использование

- **Двойной Cmd+C** — перевод выделенного текста; окно появляется у курсора. Интервал
  между нажатиями настраивается (300–1000 мс, по умолчанию 500 мс); функцию можно
  выключить в меню трея или в настройках. Копирование из менеджеров паролей
  (`ConcealedType`/`TransientType`) игнорируется.
- **Левый клик по иконке** — окно с пустым полем для ручного ввода, Enter — перевести.
- **Правый клик (или Control+клик)** — меню: «Двойной Cmd+C», «Настройки…», «Выход».
- **📌** — закрепить окно: оно остаётся на экране, перетаскивается за ручку в заголовке,
  позиция запоминается; новые переводы появляются в нём же.
- **✕** — закрыть окно в любом режиме.
- **Esc**, клик мимо окна или переключение на другое приложение закрывают попап
  (закреплённое окно — только по ✕).
- **🔊** — произнести слово.
- **📋** — скопировать перевод; это копирование не запускает новый перевод.

### Запуск при входе в систему

Работает только для бандла из `/Applications`: `make install`, затем включить
«Запускать при входе в систему» в настройках. Если macOS требует подтверждения, настройки
откроют «Объекты входа».

## Архитектура

- `EnglCore` (library) — вся логика без AppKit/SwiftUI: модели, `TextNormalizer`,
  `QueryClassifier`, `Router` с кешем, провайдеры, `ClipboardWatcher` и
  `DoubleCopyDetector`, `TranslationController`, `AppSettings`, `PopupGeometry`.
  Платформенные API (HTTP, буфер, Keychain, Apple Translation, UserDefaults) скрыты
  за протоколами и в тестах подменяются фейками.
- `Engl` (executable) — `AppDelegate`, трей, адаптер `NSPasteboard`, плавающая
  `NSPanel`, SwiftUI-вьюхи, окно настроек. Ресурсов в target нет.

Поток данных:

```
двойной Cmd+C / ручной ввод
  → TranslationController.translate      # отменяет предыдущий запрос
    → TextNormalizer → QueryClassifier    # язык en/ru, слово или предложение
    → Router (кеш → цепочка провайдеров)
  → state: idle | loading | result | failed → панель
```

**Точка расширения — `TranslationProvider`** (`id`, `supports(_:)`, `translate(_:)`).
Результат — `DictionaryEntry` или `TextTranslation`, не зависящие от источника. Новый
источник добавляется реализацией протокола и регистрацией в `AppEnvironment`;
UI менять не нужно.

**Фолбэк в `Router`.** Провайдеры опрашиваются по порядку (Yandex → Apple), на любую
`ProviderError` — переход к следующему. Если не ответил никто, возвращается самая
полезная ошибка: `invalidKey`/`rateLimited`/`languagePackMissing` >
`network`/`invalidResponse` > `notConfigured` > `notFound`. Кешируются только
результаты, полученные без ошибок предыдущих провайдеров; смена ключа сбрасывает кеш.

## Планы

- `ClaudeProvider`: Claude Haiku 4.5 (модель в настройках), structured output →
  `DictionaryEntry`; кнопка «Разобрать» для предложений (грамматика, идиомы).
- Постоянный кеш в SQLite, история запросов, «мой словарь» и карточки для повторения.
- `FreeDictionaryProvider` (dictionaryapi.dev): английские определения, IPA, аудио.
- OCR: выделение области экрана (ScreenCaptureKit) + распознавание текста (Vision).
- Глобальный хоткей и, при необходимости, `CGEventTap` для более надёжного двойного Cmd+C.
