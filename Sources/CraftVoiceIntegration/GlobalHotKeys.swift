import Carbon
import CraftVoiceCore

@MainActor public protocol HotKeyRegistering: AnyObject {
    func register(_ shortcut: GlobalShortcut, action: GlobalAction) throws
    func unregisterAll()
}
public enum HotKeyFailure: Error, LocalizedError {
    case invalid, system(Int32), rollback
    public var errorDescription: String? {
        switch self {
        case .invalid: "Wähle ein Tastenkürzel mit mindestens ⌃, ⌥ oder ⌘."
        case .system(let status): "Tastenkürzel nicht verfügbar (macOS \(status)). Wähle eine andere Kombination."
        case .rollback: "Tastenkürzel konnten nicht wiederhergestellt werden. Wähle eine neue Kombination."
        }
    }
}
@MainActor public final class HotKeyConfigurationManager {
    private let registrar: any HotKeyRegistering
    public private(set) var active: ShortcutConfiguration?
    public init(registrar: any HotKeyRegistering) { self.registrar = registrar }
    public func apply(_ configuration: ShortcutConfiguration) throws {
        guard configuration.valid else { throw HotKeyFailure.invalid }
        if active == configuration { return }
        let previous = active
        registrar.unregisterAll(); active = nil
        do {
            try registrar.register(configuration.toggle, action: .toggle)
            active = configuration
        } catch {
            registrar.unregisterAll()
            if let previous {
                do {
                    try registrar.register(previous.toggle, action: .toggle)
                    active = previous
                } catch { registrar.unregisterAll(); throw HotKeyFailure.rollback }
            }
            throw error
        }
    }
    public func stop() { registrar.unregisterAll(); active = nil }
}
@MainActor public final class GlobalHotKeys: HotKeyRegistering {
    public var onEvent: ((GlobalAction, Bool) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    public init() {}
    private func ensureHandler() throws {
        guard handler == nil else { return }
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr, id.signature == 0x43525643,
                let action = GlobalAction(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            // Carbon's application event target is dispatched on the main event loop.
            MainActor.assumeIsolated {
                Unmanaged<GlobalHotKeys>.fromOpaque(context).takeUnretainedValue().onEvent?(action, pressed)
            }
            return noErr
        }, specs.count, &specs, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw HotKeyFailure.system(status) }
    }
    public func register(_ shortcut: GlobalShortcut, action: GlobalAction) throws {
        try ensureHandler()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.key.code, shortcut.carbonModifiers,
            EventHotKeyID(signature: 0x43525643, id: action.rawValue), GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { throw HotKeyFailure.system(status) }
        refs.append(ref)
    }
    public func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
