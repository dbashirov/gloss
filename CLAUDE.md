# Engl

macOS menu-bar en↔ru translator (Swift 6, SwiftPM, SwiftUI + AppKit). User-facing docs: README.md (Russian).

## Commands

Always use `make`, never raw `swift test`:

- `make build` — debug build
- `make test` — unit tests (Swift Testing)
- `make coverage` — tests + `llvm-cov` report for `Sources/EnglCore`
- `make app` — release `.app` in `build/Engl.app` (`scripts/build-app.sh`), signed with
  `CODESIGN_IDENTITY` or ad-hoc
- `make run` / `make install` — build and open / copy to `/Applications`. `make run` does not
  restart a running instance (`open` just activates it): quit Engl first (`pkill -x Engl`)
  before verifying a rebuild. Never run `make install` or register login items unasked.
- `make clean` — `swift package clean` + `rm -rf build`

## Toolchain constraints (Command Line Tools only, no Xcode)

- `swift test` alone fails with `plugin for module 'TestingMacros' not found`; the Makefile
  passes `-plugin-path` to `<toolchain>/usr/lib/swift/host/plugins/testing`.
- Stale `*.private.swiftinterface` in CLT `usr/lib/swift/pm/{ManifestAPI,PluginAPI}` break
  any `Package.swift` with `platforms` — delete them if the manifest stops compiling.
- No `SwiftUIMacros` plugin: `@State` and `@Entry` do not compile. Use
  `private let x = State(initialValue: ...)` and `x.wrappedValue` / `x.projectedValue`;
  declare environment values with a manual `EnvironmentKey` (see `Views/Typography.swift`).
  `@FocusState`, `@Bindable`, `@Observable`, `@Environment` work.
- Bin path: `swift build --show-bin-path`, never hardcode `.build/release`.
- The `Engl` target has no resources (generated `Bundle.module` crashes inside `.app`).
  Bundle files live in `Resources/` and are copied by `scripts/build-app.sh`; load them from
  `Bundle.main` (`NSImage(named:)`) with a fallback for runs outside `Engl.app`.
- Icons are generated: `swift scripts/make-icons.swift [preview-dir]` redraws
  `Resources/AppIcon.icns` and the template `Resources/StatusIcon{,@2x}.png`; commit both
  the script and its output.
- Panel text sizes come from `PanelTypography(baseSize: settings.fontSize)` passed down as
  `\.typography`; views use `.font(.system(size: typography.<style>))`, not fixed text styles.

## Layout

- `Sources/EnglCore/` — models (incl. `Language` codes), `TextNormalizer`, `QueryClassifier`,
  `Router`, `TranslationController`, `AppSettings`, `AppIdentity` (bundle ID, log subsystem,
  Keychain service), `PopupGeometry`, secrets/Keychain, `YandexKey{Store,Check,Settings}`,
  `SettingsNote`, `LanguagePack{State,Download}`, presentation helpers
  (`ProviderError+Message`, `ResultPresentation`); `Providers/` (Yandex, Apple), `Clipboard/`
  (`ClipboardWatcher`, `DoubleCopyDetector`, `PasteboardReading`, `PasteAccess`).
- `Sources/Engl/` — `AppDelegate`, `AppEnvironment`, `MainMenu`, `StatusItemController`,
  `SystemPasteboard`; `Panel/` (`TranslatorPanel`, `PanelController`), `Views/` (panel SwiftUI),
  `Settings/` (settings window).
- `Tests/EnglCoreTests/` — one suite per type, each in `<Type>Tests.swift`; `Fakes/`,
  `Helpers/` (`fixture(_:)`, `Gate`, `StubURLProtocol`, tags, `UUID.v7()`, shared test data
  `runQuery`/`sentenceQuery`/`runCard`/`runText`/`UnexpectedError` in `TestData.swift`),
  `Fixtures/` (Yandex JSON).

## Module rules

- `EnglCore` (library): all logic, no AppKit/SwiftUI imports. `Engl` (executable): AppKit/SwiftUI
  shell only; keep it thin and move testable logic (incl. pure UI math like `PopupGeometry`)
  into `EnglCore`.
- New translation sources are added only as a `TranslationProvider` and registered in
  `AppEnvironment`; results go into the source-independent `DictionaryEntry`/`TextTranslation`.
  Providers map failures to `ProviderError` (so `Router` falls back) and cancellation to
  `CancellationError`. Add a footer name in `ProviderInfo.info(for:)`.
- UI and error strings are Russian. A new `ProviderError` case needs `message`, `action`,
  a `Router` priority and a row in `ProviderErrorMessageTests.mapsErrorToAction`
  (`CaseIterable` tests cover the rest).
- Platform APIs (HTTP, pasteboard, Keychain, Apple Translation, UserDefaults, clock) stay behind
  protocols/injection; fakes live in `Tests/EnglCoreTests/Fakes`.

## Testing conventions

- Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), `@testable import EnglCore`.
- Every code change in `EnglCore` comes with tests; UI in `Engl` is checked manually.
- Fakes: `FakeProvider`, `FakeHTTPClient`, `FakeTextTranslator` (status per direction),
  `FakeSecretStore` are thread-safe via `Mutex` from `Synchronization`; `FakePasteboard` is
  `@MainActor` like `PasteboardReading`. Tests of other types use these fakes, not
  production stores such as `InMemorySecretStore`; data used by several suites goes to
  `Helpers/TestData.swift`, not into `private let` copies.
- Use `Gate` (ignores cancellation) to hold a fake provider; suites that wait on streams
  carry `.timeLimit(.minutes(1))`. A test that cancels "the current task" does it inside
  its own `Task { }`, never the test's task.
- Yandex JSON fixtures in `Tests/EnglCoreTests/Fixtures/`, loaded via `Bundle.module`.
- Keychain tests use a unique service `com.dbashirov.engl.tests.<UUIDv7>` and delete it in
  `defer`; never touch the real `com.dbashirov.engl` items. They are tagged `.keychain`
  (need an unlocked login keychain).
- `UserDefaults` tests use a unique absolute-path suite in the temp directory and remove it in
  `defer` (named suites leave plists in `~/Library/Preferences`).
- `ClipboardWatcher` logic is driven by manual `tick()` (`pollInterval: nil`); only
  `ClipboardWatcherLoopTests` run the real 1 ms loop.
- `URLSessionHTTPClient` is tested through `StubURLProtocol`; tests never hit the network.
- Integration tests on real system services are gated with
  `@Suite(.enabled("reason", asyncCondition))`.

## AppKit/SwiftUI gotchas

- An accessory app still needs `NSApp.mainMenu` (`MainMenu.swift`), otherwise text fields get
  no Cmd+C/V/A and windows no Cmd+W.
- `TranslatorPanel` is `.borderless` + `.resizable` + `.nonactivatingPanel` with
  `canBecomeKey = true`; Esc is
  caught in `sendEvent(_:)` (the field editor would take it for completion) and Cmd+W in
  `performClose(_:)`. Dragging uses `WindowDragGesture` in `HeaderView`.
- `PanelController` defers resizing to the next main-actor turn: the hosting view reports size
  changes mid-layout. Own placements are told from user drags with a 1 pt tolerance.
- The panel follows its content (`hostingView.sizingOptions = [.intrinsicContentSize]`) until
  the user resizes it by an edge (live resize) or `ResizeGrip`; then `AppSettings.panelSize`
  is set and the sizing options are cleared so the content's size does not fight the user's.
  The grip drag is tracked by the screen cursor (`NSEvent.mouseLocation`): the panel moves
  under the gesture while it resizes.
- The status item menu is attached only while shown; kept, it would swallow left clicks.
- Translation framework objects are not `Sendable`: create them per call; the
  `.translationTask` action is a `nonisolated` method; the pack download dialog needs an
  active key window (`NSApp.activate()` first).
- `AppSettings` uses stored properties with `didSet`: SwiftUI does not observe computed
  properties over `UserDefaults`. `doubleCopyInterval` is a `Duration` stored as integer
  milliseconds; the legacy seconds key from earlier builds is migrated on load.
- Double-copy settings reach the watcher through one channel: `AppDelegate` subscribes with
  `AppSettings.observeDoubleCopy`; the tray menu and the settings window only change
  `AppSettings`.

## Debugging

- Logs: `log stream --predicate 'subsystem == "com.dbashirov.engl"'`.
- Yandex fixtures were written from the docs, not checked against a real response.
- Manual UI checklist: Post-Completion in the plan (`docs/plans/`, later
  `docs/plans/completed/`).

## Code style

- Line length ≤120 (hard), aim for 60–90; wrap arguments/conditions sensibly.
- Minimal comments: only for non-obvious decisions or external requirements, one line.
  Comments inside function bodies start lowercase.
- `///` documents what a declaration is or does: a type's doc starts with the type name
  ("Router answers…"), a method's with a verb ("Returns…"), a property's is a noun phrase.
  A lowercase `//` above a declaration explains why it is implemented that way
  (e.g. why an AppKit override exists).
- Views: one non-private view per file; private subviews may stay next to their only user.
- Literal URLs are `static let` constants built with `URL(string: "...")!`.
- Never name a variable `t` (use meaningful names).
- UUIDs are v7 (`UUID.v7()` helper in `Tests/EnglCoreTests/Helpers/UUIDv7.swift`).
- Idiomatic Swift 6 strict concurrency: `Sendable` types, `@MainActor` for UI/pasteboard,
  errors thrown, not logged and swallowed.
