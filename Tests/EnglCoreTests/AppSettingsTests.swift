import CoreGraphics
import Foundation
import Testing
@testable import EnglCore

/// makeSuiteName returns a unique absolute-path suite: cfprefsd leaves an empty plist
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
        #expect(settings.doubleCopyInterval == 0.5)
        #expect(!settings.isPinned)
        #expect(settings.pinnedTopLeft == nil)
    }

    @Test func reloadsSavedValues() throws {
        let suiteName = makeSuiteName()
        defer { removeSuite(suiteName) }
        let settings = AppSettings(defaults: try makeDefaults(suiteName))

        settings.doubleCopyEnabled = false
        settings.doubleCopyInterval = 0.8
        settings.isPinned = true
        settings.pinnedTopLeft = CGPoint(x: 120.5, y: -40)

        let reloaded = AppSettings(defaults: try makeDefaults(suiteName))
        #expect(!reloaded.doubleCopyEnabled)
        #expect(reloaded.doubleCopyInterval == 0.8)
        #expect(reloaded.isPinned)
        #expect(reloaded.pinnedTopLeft == CGPoint(x: 120.5, y: -40))
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
}
