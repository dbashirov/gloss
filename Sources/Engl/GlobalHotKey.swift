import Carbon.HIToolbox
import EnglCore
import Observation

/// GlobalHotKey calls its action when its key combination is pressed in any app.
/// Carbon hot keys need neither Accessibility nor Input Monitoring access.
@MainActor
@Observable
final class GlobalHotKey {
    // 'Engl'
    private static let signature: OSType = 0x456E_676C

    /// The combination to register; `nil` turns the hot key off.
    var combination: HotKey? {
        didSet { update() }
    }

    /// Releases the combination while a new one is recorded: pressing it must reach the recorder.
    var isSuspended = false {
        didSet { update() }
    }

    /// Whether another app holds the combination.
    private(set) var isTaken = false

    @ObservationIgnored private let action: () -> Void
    @ObservationIgnored private var hotKey: EventHotKeyRef?
    @ObservationIgnored private var handler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    private func update() {
        unregister()
        guard let combination, !isSuspended else {
            isTaken = false
            return
        }
        installHandler()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(combination.keyCode),
            combination.modifiers.carbonFlags,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        isTaken = status != noErr
    }

    private func unregister() {
        guard let hotKey else {
            return
        }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
    }

    // the instance lives as long as the app: the handler keeps an unretained pointer to it
    private func installHandler() {
        guard handler == nil else {
            return
        }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                // Carbon delivers application events on the main thread
                MainActor.assumeIsolated {
                    Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().action()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }
}

private extension HotKey.Modifiers {
    var carbonFlags: UInt32 {
        let flags: [(HotKey.Modifiers, Int)] = [
            (.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey),
        ]
        return flags.reduce(0) { result, flag in
            contains(flag.0) ? result | UInt32(flag.1) : result
        }
    }
}
