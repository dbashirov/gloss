import Carbon.HIToolbox

/// GlobalHotKey calls its action when its key combination is pressed in any app.
/// Carbon hot keys need neither Accessibility nor Input Monitoring access.
@MainActor
final class GlobalHotKey {
    // 'Engl'
    private static let signature: OSType = 0x456E_676C

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// `keyCode` is a `kVK_` code, `modifiers` a mask of `cmdKey`, `shiftKey` and the like.
    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = UInt32(modifiers)
        self.action = action
    }

    var isRegistered: Bool {
        hotKey != nil
    }

    /// Returns `false` when another app holds the combination.
    @discardableResult
    func register() -> Bool {
        guard hotKey == nil else {
            return true
        }
        installHandler()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let target = GetApplicationEventTarget()
        return RegisterEventHotKey(keyCode, modifiers, id, target, 0, &hotKey) == noErr
    }

    func unregister() {
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
