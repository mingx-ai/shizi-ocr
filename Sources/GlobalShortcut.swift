import Carbon
import Foundation

final class GlobalShortcut {
    private static let identifier = EventHotKeyID(signature: 0x534F4352, id: 1) // SOCR
    private let action: () -> Void
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init?(_ action: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        self.action = action
        let target = GetApplicationEventTarget()
        var kind = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(target, { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == GlobalShortcut.identifier.signature,
                  id.id == GlobalShortcut.identifier.id else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { [weak shortcut] in shortcut?.action() }
            return noErr
        }, 1, &kind, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return nil }

        let registered = RegisterEventHotKey(UInt32(kVK_ANSI_2), UInt32(cmdKey | shiftKey),
                                             Self.identifier, target, UInt32(kEventHotKeyExclusive), &hotKey)
        guard registered == noErr else { return nil }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
