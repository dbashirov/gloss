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
        static let pinnedOriginX = "pinnedOriginX"
        static let pinnedOriginY = "pinnedOriginY"
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

    public var pinnedOrigin: CGPoint? {
        didSet { savePinnedOrigin() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        doubleCopyEnabled = defaults.object(forKey: Key.doubleCopyEnabled) as? Bool ?? true
        doubleCopyInterval = defaults.object(forKey: Key.doubleCopyInterval) as? Double
            ?? Self.defaultDoubleCopyInterval
        isPinned = defaults.bool(forKey: Key.isPinned)
        pinnedOrigin = Self.loadPinnedOrigin(from: defaults)
    }

    private func savePinnedOrigin() {
        guard let pinnedOrigin else {
            defaults.removeObject(forKey: Key.pinnedOriginX)
            defaults.removeObject(forKey: Key.pinnedOriginY)
            return
        }
        defaults.set(Double(pinnedOrigin.x), forKey: Key.pinnedOriginX)
        defaults.set(Double(pinnedOrigin.y), forKey: Key.pinnedOriginY)
    }

    private static func loadPinnedOrigin(from defaults: UserDefaults) -> CGPoint? {
        guard let x = defaults.object(forKey: Key.pinnedOriginX) as? Double,
              let y = defaults.object(forKey: Key.pinnedOriginY) as? Double
        else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }
}
