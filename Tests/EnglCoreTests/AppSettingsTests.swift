import CoreGraphics
import Foundation
import Testing
@testable import EnglCore

/// Returns a unique absolute-path suite: cfprefsd leaves an empty plist
/// in ~/Library/Preferences for a removed named suite, a temp directory is safe to drop.
private func makeSuiteName() -> String {
    FileManager.default.temporaryDirectory
        .appending(path: "engl-tests-\(UUID.v7().uuidString)/settings")
        .path(percentEncoded: false)
}

private func makeDefaults(_ suiteName: String) throws -> UserDefaults {
    try #require(UserDefaults(suiteName: suiteName))
}

private func removeSuite(_ suiteName: String) {
    UserDefaults().removePersistentDomain(forName: suiteName)
    let directory = URL(filePath: suiteName).deletingLastPathComponent()
    try? FileManager.default.removeItem(at: directory)
}

@MainActor
struct AppSettingsTests {
    @Test func usesDefaultValues() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }

        let settings = AppSettings(defaults: try makeDefaults(suiteName))

        #expect(settings.doubleCopyEnabled)
        #expect(settings.doubleCopyInterval == DoubleCopyDetector.defaultInterval)
        #expect(!settings.isPinned)
        #expect(settings.pinnedTopLeft == nil)
        #expect(settings.panelSize == nil)
        #expect(settings.fontSize == PanelTypography.defaultSize)
        #expect(settings.panelFont == .system)
        #expect(settings.screenTextHotKeyEnabled)
        #expect(settings.screenTextHotKey == .screenTextDefault)
    }

    @Test func reloadsSavedValues() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let settings = AppSettings(defaults: try makeDefaults(suiteName))

        settings.doubleCopyEnabled = false
        settings.doubleCopyInterval = .milliseconds(800)
        settings.isPinned = true
        settings.pinnedTopLeft = CGPoint(x: 120.5, y: -40)
        settings.panelSize = CGSize(width: 520.5, height: 640)
        settings.fontSize = 17
        settings.panelFont = .family("Georgia")
        settings.screenTextHotKeyEnabled = false
        settings.screenTextHotKey = HotKey(keyCode: 0x11, modifiers: [.control, .option])

        let reloaded = AppSettings(defaults: try makeDefaults(suiteName))
        #expect(!reloaded.doubleCopyEnabled)
        #expect(reloaded.doubleCopyInterval == .milliseconds(800))
        #expect(reloaded.isPinned)
        #expect(reloaded.pinnedTopLeft == CGPoint(x: 120.5, y: -40))
        #expect(reloaded.panelSize == CGSize(width: 520.5, height: 640))
        #expect(reloaded.fontSize == 17)
        #expect(reloaded.panelFont == .family("Georgia"))
        #expect(!reloaded.screenTextHotKeyEnabled)
        #expect(reloaded.screenTextHotKey == HotKey(keyCode: 0x11, modifiers: [.control, .option]))
    }

    @Test(arguments: [
        (0x08, HotKey.Modifiers.command.rawValue),
        (0x13, nil),
    ])
    func unusableStoredHotKeyFallsBackToDefault(keyCode: Int, modifiers: Int?) throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        defaults.set(keyCode, forKey: AppSettings.Key.screenTextHotKeyCode)
        if let modifiers {
            defaults.set(modifiers, forKey: AppSettings.Key.screenTextHotKeyModifiers)
        }

        #expect(AppSettings(defaults: defaults).screenTextHotKey == .screenTextDefault)
    }

    @Test func unknownStoredFontFallsBackToSystem() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        defaults.set("fancy", forKey: AppSettings.Key.panelFont)

        #expect(AppSettings(defaults: defaults).panelFont == .system)
    }

    @Test func clampsStoredFontSize() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        defaults.set(99.0, forKey: AppSettings.Key.fontSize)

        #expect(AppSettings(defaults: defaults).fontSize == PanelTypography.sizeRange.upperBound)
    }

    @Test func clearsPanelSize() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        let settings = AppSettings(defaults: defaults)
        settings.panelSize = CGSize(width: 500, height: 400)

        settings.panelSize = nil

        #expect(AppSettings(defaults: try makeDefaults(suiteName)).panelSize == nil)
        #expect(defaults.object(forKey: AppSettings.Key.panelWidth) == nil)
        #expect(defaults.object(forKey: AppSettings.Key.panelHeight) == nil)
    }

    @Test func ignoresIncompletePanelSize() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        defaults.set(500.0, forKey: AppSettings.Key.panelWidth)

        #expect(AppSettings(defaults: defaults).panelSize == nil)
    }

    @Test func clearsPinnedTopLeft() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        let settings = AppSettings(defaults: defaults)
        settings.pinnedTopLeft = CGPoint(x: 10, y: 20)

        settings.pinnedTopLeft = nil

        #expect(AppSettings(defaults: try makeDefaults(suiteName)).pinnedTopLeft == nil)
        #expect(defaults.object(forKey: AppSettings.Key.pinnedTopLeftX) == nil)
        #expect(defaults.object(forKey: AppSettings.Key.pinnedTopLeftY) == nil)
    }

    @Test func ignoresIncompletePinnedTopLeft() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        defaults.set(10.0, forKey: AppSettings.Key.pinnedTopLeftX)

        #expect(AppSettings(defaults: defaults).pinnedTopLeft == nil)
    }

    @Test func keepsExplicitFalseAndZeroValues() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let settings = AppSettings(defaults: try makeDefaults(suiteName))

        settings.doubleCopyEnabled = false
        settings.pinnedTopLeft = .zero

        let reloaded = AppSettings(defaults: try makeDefaults(suiteName))
        #expect(!reloaded.doubleCopyEnabled)
        #expect(reloaded.pinnedTopLeft == .zero)
    }

    @Test func suitesAreIsolated() throws {
        let first = makeSuiteName()
        let second = makeSuiteName()
        defer {
            removeSuite(first)
            removeSuite(second)
        }

        AppSettings(defaults: try makeDefaults(first)).isPinned = true

        #expect(!AppSettings(defaults: try makeDefaults(second)).isPinned)
    }

    @Test func migratesLegacyIntervalInSeconds() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        defaults.set(0.7, forKey: AppSettings.Key.legacyDoubleCopyInterval)

        let settings = AppSettings(defaults: defaults)

        #expect(settings.doubleCopyInterval == .milliseconds(700))
        #expect(defaults.object(forKey: AppSettings.Key.legacyDoubleCopyInterval) == nil)
        #expect(defaults.integer(forKey: AppSettings.Key.doubleCopyIntervalMilliseconds) == 700)
        #expect(AppSettings(defaults: defaults).doubleCopyInterval == .milliseconds(700))
    }

    @Test func storesIntervalInMilliseconds() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let defaults = try makeDefaults(suiteName)
        let settings = AppSettings(defaults: defaults)

        settings.doubleCopyInterval = .milliseconds(650)

        #expect(defaults.integer(forKey: AppSettings.Key.doubleCopyIntervalMilliseconds) == 650)
    }

    @Test(.timeLimit(.minutes(1)))
    func reportsDoubleCopyChangesOfOneTurnOnce() async throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let settings = AppSettings(defaults: try makeDefaults(suiteName))
        let (changes, continuation) = AsyncStream.makeStream(of: (Bool, Duration).self)
        settings.observeDoubleCopy {
            continuation.yield((settings.doubleCopyEnabled, settings.doubleCopyInterval))
        }
        var iterator = changes.makeAsyncIterator()

        settings.doubleCopyEnabled = false
        settings.doubleCopyInterval = .milliseconds(800)
        let first = try #require(await iterator.next())
        settings.isPinned = true
        settings.doubleCopyEnabled = true
        let second = try #require(await iterator.next())

        #expect(first == (false, Duration.milliseconds(800)))
        #expect(second == (true, Duration.milliseconds(800)))
    }

    @Test(.timeLimit(.minutes(1)))
    func reportsScreenTextHotKeyChanges() async throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let settings = AppSettings(defaults: try makeDefaults(suiteName))
        let (changes, continuation) = AsyncStream.makeStream(of: Bool.self)
        settings.observeScreenTextHotKey {
            continuation.yield(settings.screenTextHotKeyEnabled)
        }
        var iterator = changes.makeAsyncIterator()

        settings.screenTextHotKeyEnabled = false
        let first = try #require(await iterator.next())
        settings.doubleCopyEnabled = false
        settings.screenTextHotKeyEnabled = true
        let second = try #require(await iterator.next())
        settings.screenTextHotKey = HotKey(keyCode: 0x11, modifiers: [.control, .option])
        let third = try #require(await iterator.next())

        #expect(!first)
        #expect(second)
        #expect(third)
    }
}
