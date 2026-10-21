import AppKit
import Carbon.HIToolbox
import GlossCore
import Observation
import SwiftUI

/// HotKeyRecorder shows a hot key; a click records a new one from the next key press.
struct HotKeyRecorder: View {
    let hotKey: HotKey
    /// A combination already given to another action, which a recording rejects.
    let reserved: HotKey
    let onRecord: (HotKey) -> Void
    /// Called with `true` when recording starts and `false` when it ends.
    let onRecordingChange: (Bool) -> Void

    private let recording = State(initialValue: HotKeyRecording())

    var body: some View {
        let recording = recording.wrappedValue
        VStack(alignment: .trailing, spacing: 4) {
            Button(recording.isActive ? "Нажмите сочетание…" : KeyNames.displayName(of: hotKey)) {
                if recording.isActive {
                    recording.stop()
                } else {
                    recording.start(
                        reserved: reserved,
                        onRecord: onRecord,
                        onChange: onRecordingChange
                    )
                }
            }
            .help("Нажмите и введите новое сочетание, Esc - отмена")
            if let hint = recording.hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            recording.stop()
        }
    }
}

/// HotKeyRecording takes the next key press in its window as a new hot key.
@MainActor
@Observable
private final class HotKeyRecording {
    private(set) var isActive = false
    private(set) var hint: String?

    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var resignObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var reserved: HotKey?
    @ObservationIgnored private var onRecord: (HotKey) -> Void = { _ in }
    @ObservationIgnored private var onChange: (Bool) -> Void = { _ in }

    func start(
        reserved: HotKey,
        onRecord: @escaping (HotKey) -> Void,
        onChange: @escaping (Bool) -> Void
    ) {
        guard !isActive, let window = NSApp.keyWindow else {
            return
        }
        self.window = window
        self.reserved = reserved
        self.onRecord = onRecord
        self.onChange = onChange
        isActive = true
        hint = nil
        onChange(true)
        // the key press must not reach the form or the menu (⌘W would close the window)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let isTaken = MainActor.assumeIsolated {
                self?.take(event) ?? false
            }
            return isTaken ? nil : event
        }
        // another window or app takes the keys: the global hot key is suspended meanwhile
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
    }

    func stop() {
        guard isActive else {
            return
        }
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        monitor = nil
        resignObserver = nil
        window = nil
        isActive = false
        hint = nil
        onChange(false)
    }

    /// Returns `false` for a key press in another window: it goes on as usual.
    private func take(_ event: NSEvent) -> Bool {
        guard event.window === window else {
            return false
        }
        let modifiers = HotKey.Modifiers(event.modifierFlags)
        if Int(event.keyCode) == kVK_Escape, modifiers.isEmpty {
            stop()
            return true
        }
        let hotKey = HotKey(keyCode: Int(event.keyCode), modifiers: modifiers)
        guard hotKey.isAllowed else {
            hint = "Нужны два модификатора, например ⌘⇧ или ⌃⌥"
            return true
        }
        guard hotKey != reserved else {
            hint = "Это сочетание уже занято в Gloss"
            return true
        }
        let onRecord = onRecord
        stop()
        onRecord(hotKey)
        return true
    }
}
