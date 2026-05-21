import Carbon.HIToolbox
import Foundation

final class HotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: ((Bool) -> Void)?

    func register(modifiers: UInt32 = UInt32(controlKey | optionKey), keyCode: UInt32 = 49, callback: @escaping (Bool) -> Void) {
        unregister()
        self.callback = callback

        var eventSpecs = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr, hotKeyID.id == 1 {
                    let eventKind = GetEventKind(eventRef)
                    let isPressed = eventKind == UInt32(kEventHotKeyPressed)

                    let controller = Unmanaged<HotKeyController>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    DispatchQueue.main.async {
                        controller.callback?(isPressed)
                    }
                }
                return noErr
            },
            2,
            &eventSpecs,
            userData,
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x57687370), id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
