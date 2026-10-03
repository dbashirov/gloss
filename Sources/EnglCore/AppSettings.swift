import CoreGraphics
import Foundation
import Observation

/// AppSettings keeps user preferences in `UserDefaults`. Properties are stored, not
/// computed over the defaults: SwiftUI observes only stored properties.
@MainActor
@Observable
public final class AppSettings {
    enum Key {
        static let doubleCopyEnabled = "doubleCopyEnabled"
        static let doubleCopyIntervalMilliseconds = "doubleCopyIntervalMilliseconds"
        /// Seconds as `Double`, written by earlier builds.
        static let legacyDoubleCopyInterval = "doubleCopyInterval"
        static let isPinned = "isPinned"
        static let pinnedTopLeftX = "pinnedTopLeftX"
        static let pinnedTopLeftY = "pinnedTopLeftY"
        static let panelWidth = "panelWidth"
        static let panelHeight = "panelHeight"
    }

    public var doubleCopyEnabled: Bool {
        didSet { defaults.set(doubleCopyEnabled, forKey: Key.doubleCopyEnabled) }
    }

    /// Maximum time between two copies that make a double Cmd+C.
    public var doubleCopyInterval: Duration {
        didSet { saveDoubleCopyInterval() }
    }

    public var isPinned: Bool {
        didSet { defaults.set(isPinned, forKey: Key.isPinned) }
    }

    /// Top-left corner of the pinned panel: its height follows the content.
    public var pinnedTopLeft: CGPoint? {
        didSet { savePinnedTopLeft() }
    }

    /// Panel size chosen by the user; `nil` sizes the panel to its content.
    public var panelSize: CGSize? {
        didSet { savePanelSize() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        doubleCopyEnabled = defaults.object(forKey: Key.doubleCopyEnabled) as? Bool ?? true
        doubleCopyInterval = Self.loadDoubleCopyInterval(from: defaults)
        isPinned = defaults.bool(forKey: Key.isPinned)
        pinnedTopLeft = Self.loadPinnedTopLeft(from: defaults)
        panelSize = Self.loadPanelSize(from: defaults)
        if defaults.object(forKey: Key.legacyDoubleCopyInterval) != nil {
            saveDoubleCopyInterval()
        }
    }

    /// Calls `onChange` after every change of `doubleCopyEnabled` or `doubleCopyInterval`
    /// while the settings exist; changes made in one main-actor turn are reported once.
    public func observeDoubleCopy(_ onChange: @escaping @MainActor @Sendable () -> Void) {
        withObservationTracking {
            _ = doubleCopyEnabled
            _ = doubleCopyInterval
        } onChange: { [weak self] in
            // runs before the new value is stored and only once per registration
            Task { @MainActor in
                guard let self else {
                    return
                }
                onChange()
                self.observeDoubleCopy(onChange)
            }
        }
    }

    private func saveDoubleCopyInterval() {
        let milliseconds = (doubleCopyInterval / .milliseconds(1)).rounded()
        defaults.set(Int(milliseconds), forKey: Key.doubleCopyIntervalMilliseconds)
        defaults.removeObject(forKey: Key.legacyDoubleCopyInterval)
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

    private func savePanelSize() {
        guard let panelSize else {
            defaults.removeObject(forKey: Key.panelWidth)
            defaults.removeObject(forKey: Key.panelHeight)
            return
        }
        defaults.set(Double(panelSize.width), forKey: Key.panelWidth)
        defaults.set(Double(panelSize.height), forKey: Key.panelHeight)
    }

    private static func loadDoubleCopyInterval(from defaults: UserDefaults) -> Duration {
        if let milliseconds = defaults.object(forKey: Key.doubleCopyIntervalMilliseconds) as? Int {
            return .milliseconds(milliseconds)
        }
        if let seconds = defaults.object(forKey: Key.legacyDoubleCopyInterval) as? Double {
            return .milliseconds(Int((seconds * 1000).rounded()))
        }
        return DoubleCopyDetector.defaultInterval
    }

    private static func loadPinnedTopLeft(from defaults: UserDefaults) -> CGPoint? {
        guard let x = defaults.object(forKey: Key.pinnedTopLeftX) as? Double,
              let y = defaults.object(forKey: Key.pinnedTopLeftY) as? Double
        else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }

    private static func loadPanelSize(from defaults: UserDefaults) -> CGSize? {
        guard let width = defaults.object(forKey: Key.panelWidth) as? Double,
              let height = defaults.object(forKey: Key.panelHeight) as? Double
        else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}
