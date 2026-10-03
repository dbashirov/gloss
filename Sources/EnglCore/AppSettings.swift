import CoreGraphics
import Foundation
import Observation

/// AppSettings keeps user preferences in `UserDefaults`. Properties are stored, not
/// computed over the defaults: SwiftUI observes only stored properties.
@MainActor
@Observable
public final class AppSettings {
    public static let defaultDoubleCopyInterval = 0.5

    enum Key {
        static let doubleCopyEnabled = "doubleCopyEnabled"
        static let doubleCopyInterval = "doubleCopyInterval"
        static let isPinned = "isPinned"
        static let pinnedTopLeftX = "pinnedTopLeftX"
        static let pinnedTopLeftY = "pinnedTopLeftY"
    }

    public var doubleCopyEnabled: Bool {
        didSet { defaults.set(doubleCopyEnabled, forKey: Key.doubleCopyEnabled) }
    }

    /// Seconds between two copies that make a double Cmd+C.
    public var doubleCopyInterval: Double {
        didSet { defaults.set(doubleCopyInterval, forKey: Key.doubleCopyInterval) }
    }

    public var isPinned: Bool {
        didSet { defaults.set(isPinned, forKey: Key.isPinned) }
    }

    /// Top-left corner of the pinned panel: its height follows the content.
    public var pinnedTopLeft: CGPoint? {
        didSet { savePinnedTopLeft() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        doubleCopyEnabled = defaults.object(forKey: Key.doubleCopyEnabled) as? Bool ?? true
        doubleCopyInterval = defaults.object(forKey: Key.doubleCopyInterval) as? Double
            ?? Self.defaultDoubleCopyInterval
        isPinned = defaults.bool(forKey: Key.isPinned)
        pinnedTopLeft = Self.loadPinnedTopLeft(from: defaults)
    }

    private func savePinnedTopLeft() {
        guard let pinnedTopLeft else {
            defaults.removeObject(forKey: Key.pinnedTopLeftX)
            defaults.removeObject(forKey: Key.pinnedTopLeftY)
            return
        }
        defaults.set(Double(pinnedTopLeft.x), forKey: Key.pinnedTopLeftX)
        defaults.set(Double(pinnedTopLeft.y), forKey: Key.pinnedTopLeftY)
    }

    private static func loadPinnedTopLeft(from defaults: UserDefaults) -> CGPoint? {
        guard let x = defaults.object(forKey: Key.pinnedTopLeftX) as? Double,
              let y = defaults.object(forKey: Key.pinnedTopLeftY) as? Double
        else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }
}
