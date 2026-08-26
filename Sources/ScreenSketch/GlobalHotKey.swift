import Carbon

final class GlobalHotKey {
    var onToggle: (() -> Void)?
    var onClear: (() -> Void)?
    var onUndo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onCut: (() -> Void)?
    var onPaste: (() -> Void)?
    var onDelete: (() -> Void)?

    private var toggleHotKeyRef: EventHotKeyRef?
    private var clearHotKeyRef: EventHotKeyRef?
    private var undoHotKeyRef: EventHotKeyRef?
    private var copyHotKeyRef: EventHotKeyRef?
    private var cutHotKeyRef: EventHotKeyRef?
    private var pasteHotKeyRef: EventHotKeyRef?
    private var deleteHotKeyRef: EventHotKeyRef?
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
                    case 4: hotKeys.onCopy?()
                    case 5: hotKeys.onCut?()
                    case 6: hotKeys.onPaste?()
                    case 7: hotKeys.onDelete?()
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

    func setEditingShortcuts(copyCutDeleteEnabled: Bool, pasteEnabled: Bool) {
        if copyCutDeleteEnabled {
            if copyHotKeyRef == nil { copyHotKeyRef = registerHotKey(keyCode: UInt32(kVK_ANSI_C), id: 4) }
            if cutHotKeyRef == nil { cutHotKeyRef = registerHotKey(keyCode: UInt32(kVK_ANSI_X), id: 5) }
            if deleteHotKeyRef == nil { deleteHotKeyRef = registerHotKey(keyCode: UInt32(kVK_Delete), id: 7) }
        } else {
            Self.unregister(&copyHotKeyRef)
            Self.unregister(&cutHotKeyRef)
            Self.unregister(&deleteHotKeyRef)
        }

        if pasteEnabled {
            if pasteHotKeyRef == nil { pasteHotKeyRef = registerHotKey(keyCode: UInt32(kVK_ANSI_V), id: 6) }
        } else {
            Self.unregister(&pasteHotKeyRef)
        }
    }

    private func registerHotKey(keyCode: UInt32, id: UInt32) -> EventHotKeyRef? {
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x534B4554, id: id)
        let result = RegisterEventHotKey(
            keyCode,
            UInt32(cmdKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        return result == noErr ? reference : nil
    }

    private static func unregister(_ reference: inout EventHotKeyRef?) {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
    }

    deinit {
        if let toggleHotKeyRef { UnregisterEventHotKey(toggleHotKeyRef) }
        if let clearHotKeyRef { UnregisterEventHotKey(clearHotKeyRef) }
        if let undoHotKeyRef { UnregisterEventHotKey(undoHotKeyRef) }
        Self.unregister(&copyHotKeyRef)
        Self.unregister(&cutHotKeyRef)
        Self.unregister(&pasteHotKeyRef)
        Self.unregister(&deleteHotKeyRef)
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
