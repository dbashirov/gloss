import AppKit
import Carbon.HIToolbox
import EnglCore
import Observation
import SwiftUI

/// HotKeyRecorder shows a hot key; a click records a new one from the next key press.
struct HotKeyRecorder: View {
    let hotKey: HotKey
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
                    recording.start(onRecord: onRecord, onChange: onRecordingChange)
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

/// HotKeyRecording takes the next key press in the app as a new hot key.
@MainActor
@Observable
private final class HotKeyRecording {
    private(set) var isActive = false
    private(set) var hint: String?

    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var resignObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var onRecord: (HotKey) -> Void = { _ in }
    @ObservationIgnored private var onChange: (Bool) -> Void = { _ in }

    func start(onRecord: @escaping (HotKey) -> Void, onChange: @escaping (Bool) -> Void) {
        guard !isActive else {
            return
        }
        self.onRecord = onRecord
        self.onChange = onChange
        isActive = true
        hint = nil
        onChange(true)
        // the key press must not reach the form or the menu (⌘W would close the window)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return nil
        }
        // switching to another app ends recording: the global hot key is suspended meanwhile
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
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
        isActive = false
        hint = nil
        onChange(false)
    }

    private func handle(_ event: NSEvent) {
        let modifiers = HotKey.Modifiers(event.modifierFlags)
        if Int(event.keyCode) == kVK_Escape, modifiers.isEmpty {
            stop()
            return
        }
        let hotKey = HotKey(keyCode: Int(event.keyCode), modifiers: modifiers)
        guard hotKey.isAllowed else {
            hint = "Нужны два модификатора, например ⌘⇧ или ⌃⌥"
            return
        }
        let onRecord = onRecord
        stop()
        onRecord(hotKey)
    }
}
