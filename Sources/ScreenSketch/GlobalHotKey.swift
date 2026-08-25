import Carbon

final class GlobalHotKey {
    var onToggle: (() -> Void)?
    var onClear: (() -> Void)?
    var onUndo: (() -> Void)?

    private var toggleHotKeyRef: EventHotKeyRef?
    private var clearHotKeyRef: EventHotKeyRef?
    private var undoHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData,
                      GetEventClass(event) == OSType(kEventClassKeyboard),
                      GetEventKind(event) == UInt32(kEventHotKeyPressed) else {
                    return OSStatus(eventNotHandledErr)
                }

                var identifier = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard result == noErr else { return result }

                let hotKeys = Unmanaged<GlobalHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                let identifierID = identifier.id
                DispatchQueue.main.async {
                    switch identifierID {
                    case 1: hotKeys.onToggle?()
                    case 2: hotKeys.onClear?()
                    case 3: hotKeys.onUndo?()
                    default: break
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        let toggleIdentifier = EventHotKeyID(signature: 0x534B4554, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(cmdKey | shiftKey),
            toggleIdentifier,
            GetApplicationEventTarget(),
            0,
            &toggleHotKeyRef
        )

        let clearIdentifier = EventHotKeyID(signature: 0x534B4554, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_F),
            UInt32(cmdKey | shiftKey),
            clearIdentifier,
            GetApplicationEventTarget(),
            0,
            &clearHotKeyRef
        )

        let undoIdentifier = EventHotKeyID(signature: 0x534B4554, id: 3)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            undoIdentifier,
            GetApplicationEventTarget(),
            0,
            &undoHotKeyRef
        )
    }

    deinit {
        if let toggleHotKeyRef { UnregisterEventHotKey(toggleHotKeyRef) }
        if let clearHotKeyRef { UnregisterEventHotKey(clearHotKeyRef) }
        if let undoHotKeyRef { UnregisterEventHotKey(undoHotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
