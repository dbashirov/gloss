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
        static let queryFieldHeight = "queryFieldHeight"
        static let fontSize = "fontSize"
        static let panelFont = "panelFont"
        static let screenTextHotKeyEnabled = "screenTextHotKeyEnabled"
        static let screenTextHotKeyCode = "screenTextHotKeyCode"
        static let screenTextHotKeyModifiers = "screenTextHotKeyModifiers"
        static let clipboardHotKeyEnabled = "clipboardHotKeyEnabled"
        static let clipboardHotKeyCode = "clipboardHotKeyCode"
        static let clipboardHotKeyModifiers = "clipboardHotKeyModifiers"
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

    /// Query field height set with the divider; `nil` fits the field to its text.
    public var queryFieldHeight: Double? {
        didSet { saveQueryFieldHeight() }
    }

    /// Base text size of the panel in points, within `PanelTypography.sizeRange`.
    public var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Key.fontSize) }
    }

    /// Typeface of the panel text.
    public var panelFont: PanelFont {
        didSet { defaults.set(panelFont.storageValue, forKey: Key.panelFont) }
    }

    /// Whether `screenTextHotKey` selects a screen area to translate its text.
    public var screenTextHotKeyEnabled: Bool {
        didSet { defaults.set(screenTextHotKeyEnabled, forKey: Key.screenTextHotKeyEnabled) }
    }

    /// The combination that selects a screen area to translate its text.
    public var screenTextHotKey: HotKey {
        didSet {
            save(
                screenTextHotKey,
                code: Key.screenTextHotKeyCode,
                modifiers: Key.screenTextHotKeyModifiers
            )
        }
    }

    /// Whether `clipboardHotKey` translates the text on the pasteboard.
    public var clipboardHotKeyEnabled: Bool {
        didSet { defaults.set(clipboardHotKeyEnabled, forKey: Key.clipboardHotKeyEnabled) }
    }

    /// The combination that translates the text on the pasteboard, for apps where
    /// double Cmd+C does not change the pasteboard twice.
    public var clipboardHotKey: HotKey {
        didSet {
            save(
                clipboardHotKey,
                code: Key.clipboardHotKeyCode,
                modifiers: Key.clipboardHotKeyModifiers
            )
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        doubleCopyEnabled = defaults.object(forKey: Key.doubleCopyEnabled) as? Bool ?? true
        doubleCopyInterval = Self.loadDoubleCopyInterval(from: defaults)
        isPinned = defaults.bool(forKey: Key.isPinned)
        pinnedTopLeft = Self.loadPinnedTopLeft(from: defaults)
        panelSize = Self.loadPanelSize(from: defaults)
        queryFieldHeight = (defaults.object(forKey: Key.queryFieldHeight) as? Double)
            .flatMap { $0 > 0 ? $0 : nil }
        let fontSize = defaults.object(forKey: Key.fontSize) as? Double
        self.fontSize = PanelTypography.clamp(fontSize ?? PanelTypography.defaultSize)
        let storedFont = defaults.string(forKey: Key.panelFont)
        panelFont = storedFont.flatMap(PanelFont.init(storageValue:)) ?? .system
        screenTextHotKeyEnabled = defaults.object(forKey: Key.screenTextHotKeyEnabled) as? Bool
            ?? true
        let screenTextHotKey = Self.loadHotKey(
            from: defaults,
            code: Key.screenTextHotKeyCode,
            modifiers: Key.screenTextHotKeyModifiers
        ) ?? .screenTextDefault
        self.screenTextHotKey = screenTextHotKey
        clipboardHotKeyEnabled = defaults.object(forKey: Key.clipboardHotKeyEnabled) as? Bool
            ?? true
        let clipboardHotKey = Self.loadHotKey(
            from: defaults,
            code: Key.clipboardHotKeyCode,
            modifiers: Key.clipboardHotKeyModifiers
        ) ?? .clipboardDefault
        self.clipboardHotKey = Self.distinct(clipboardHotKey, from: screenTextHotKey)
        if defaults.object(forKey: Key.legacyDoubleCopyInterval) != nil {
            saveDoubleCopyInterval()
        }
    }

    /// Calls `onChange` after every change of `doubleCopyEnabled` or `doubleCopyInterval`
    /// while the settings exist; changes made in one main-actor turn are reported once.
    public func observeDoubleCopy(_ onChange: @escaping @MainActor @Sendable () -> Void) {
        observe(onChange) { settings in
            _ = settings.doubleCopyEnabled
            _ = settings.doubleCopyInterval
        }
    }

    /// Calls `onChange` after every change of a hot key or its switch, like
    /// `observeDoubleCopy(_:)`.
    public func observeHotKeys(_ onChange: @escaping @MainActor @Sendable () -> Void) {
        observe(onChange) { settings in
            _ = settings.screenTextHotKeyEnabled
            _ = settings.screenTextHotKey
            _ = settings.clipboardHotKeyEnabled
            _ = settings.clipboardHotKey
        }
    }

    private func observe(
        _ onChange: @escaping @MainActor @Sendable () -> Void,
        reading: @escaping @MainActor @Sendable (AppSettings) -> Void
    ) {
        withObservationTracking {
            reading(self)
        } onChange: { [weak self] in
            // runs before the new value is stored and only once per registration
            Task { @MainActor in
                guard let self else {
                    return
                }
                onChange()
                self.observe(onChange, reading: reading)
            }
        }
    }

    private func saveDoubleCopyInterval() {
        let milliseconds = (doubleCopyInterval / .milliseconds(1)).rounded()
        defaults.set(Int(milliseconds), forKey: Key.doubleCopyIntervalMilliseconds)
        defaults.removeObject(forKey: Key.legacyDoubleCopyInterval)
    }

    private func save(_ hotKey: HotKey, code: String, modifiers: String) {
        defaults.set(hotKey.keyCode, forKey: code)
        defaults.set(hotKey.modifiers.rawValue, forKey: modifiers)
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

    private func saveQueryFieldHeight() {
        if let queryFieldHeight {
            defaults.set(queryFieldHeight, forKey: Key.queryFieldHeight)
        } else {
            defaults.removeObject(forKey: Key.queryFieldHeight)
        }
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

    private static func loadHotKey(
        from defaults: UserDefaults,
        code: String,
        modifiers: String
    ) -> HotKey? {
        guard let keyCode = defaults.object(forKey: code) as? Int,
              let modifiers = defaults.object(forKey: modifiers) as? Int
        else {
            return nil
        }
        let hotKey = HotKey(keyCode: keyCode, modifiers: HotKey.Modifiers(rawValue: modifiers))
        return hotKey.isAllowed ? hotKey : nil
    }

    // one combination cannot do both: a screen text key set to ⌘⇧1 before the clipboard
    // key existed leaves ⌘⇧2 free
    private static func distinct(_ hotKey: HotKey, from other: HotKey) -> HotKey {
        guard hotKey == other else {
            return hotKey
        }
        return other == .clipboardDefault ? .screenTextDefault : .clipboardDefault
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
