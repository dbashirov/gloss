# Engl

macOS menu-bar en↔ru translator (Swift 6, SwiftPM, SwiftUI + AppKit). User-facing docs: README.md (Russian).

## Commands

Always use `make`, never raw `swift test`:

- `make build` — debug build
- `make test` — unit tests (Swift Testing)
- `make coverage` — tests + `llvm-cov` report for `Sources/EnglCore`
- `make app` — release `.app` in `build/Engl.app` (`scripts/build-app.sh`), signed with
  `CODESIGN_IDENTITY` or ad-hoc
- `make run` / `make install` — build and open / copy to `/Applications`

## Toolchain constraints (Command Line Tools only, no Xcode)

- `swift test` alone fails with `plugin for module 'TestingMacros' not found`; the Makefile
  passes `-plugin-path` to `<toolchain>/usr/lib/swift/host/plugins/testing`.
- Stale `*.private.swiftinterface` in CLT `usr/lib/swift/pm/{ManifestAPI,PluginAPI}` break
  any `Package.swift` with `platforms` — delete them if the manifest stops compiling.
- No `SwiftUIMacros` plugin: `@State` does not compile. Use
  `private let x = State(initialValue: ...)` and `x.wrappedValue` / `x.projectedValue`.
  `@FocusState`, `@Bindable`, `@Observable` work.
- Bin path: `swift build --show-bin-path`, never hardcode `.build/release`.
- The `Engl` target has no resources (generated `Bundle.module` crashes inside `.app`).

## Module rules

- `EnglCore` (library): all logic, no AppKit/SwiftUI imports. `Engl` (executable): AppKit/SwiftUI
  shell only; keep it thin and move testable logic (incl. pure UI math like `PopupGeometry`)
  into `EnglCore`.
- New translation sources are added only as a `TranslationProvider` and registered in
  `AppEnvironment`; results go into the source-independent `DictionaryEntry`/`TextTranslation`.
  Providers map failures to `ProviderError` (so `Router` falls back) and cancellation to
  `CancellationError`. Add a footer name in `ProviderInfo.info(for:)`.
- Platform APIs (HTTP, pasteboard, Keychain, Apple Translation, UserDefaults, clock) stay behind
  protocols/injection; fakes live in `Tests/EnglCoreTests/Fakes`.

## Testing conventions

- Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), `@testable import EnglCore`.
- Every code change in `EnglCore` comes with tests; UI in `Engl` is checked manually.
- Fakes: `FakeProvider`, `FakeHTTPClient`, `FakePasteboard`, `FakeTextTranslator`
  (thread-safe via `Mutex` from `Synchronization`).
- Yandex JSON fixtures in `Tests/EnglCoreTests/Fixtures/`, loaded via `Bundle.module`.
- Keychain tests use a unique service `com.dbashirov.engl.tests.<UUIDv7>` and delete it in
  `defer`; never touch the real `com.dbashirov.engl` items.
- `UserDefaults` tests use a unique absolute-path suite in the temp directory and remove it in
  `defer` (named suites leave plists in `~/Library/Preferences`).
- `ClipboardWatcher` is driven by manual `tick()` (`pollInterval: nil`), no real sleeping.
- Integration tests on real system services are gated with `.enabled(if:)`.

## Code style

- Line length ≤120 (hard), aim for 60–90; wrap arguments/conditions sensibly.
- Minimal comments: only for non-obvious decisions or external requirements, one line.
  Comments inside function bodies start lowercase; doc comments start with the entity name.
- Never name a variable `t` (use meaningful names).
- UUIDs are v7 (`UUID.v7()` helper in `Tests/EnglCoreTests/Helpers/UUIDv7.swift`).
- Idiomatic Swift 6 strict concurrency: `Sendable` types, `@MainActor` for UI/pasteboard,
  errors thrown, not logged and swallowed.
