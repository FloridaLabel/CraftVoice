import Testing
import Foundation
import Carbon
import CraftVoiceCore
@testable import CraftVoiceIntegration

@MainActor private final class RegistrarDouble: HotKeyRegistering {
    var current: [UInt32: GlobalShortcut] = [:]
    var reject: GlobalShortcut?
    func register(_ shortcut: GlobalShortcut, action: GlobalAction) throws {
        if shortcut == reject { throw HotKeyFailure.system(-9878) }
        current[action.rawValue] = shortcut
    }
    func unregisterAll() { current.removeAll() }
}
@Suite @MainActor struct ShortcutTests {
    @Test func nativeCarbonHandlerReceivesPressedAndReleased() throws {
        let keys = GlobalHotKeys()
        defer { keys.unregisterAll() }
        var received: [Bool] = []
        keys.onEvent = { action, pressed in if action == .toggle { received.append(pressed) } }
        try keys.register(GlobalShortcut(key: .f10, command: true, shift: true), action: .toggle)
        for kind in [kEventHotKeyPressed, kEventHotKeyReleased] {
            var event: EventRef?
            #expect(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kind), GetCurrentEventTime(), 0, &event) == noErr)
            guard let event else { Issue.record("Carbon event missing"); return }
            defer { ReleaseEvent(event) }
            var identifier = EventHotKeyID(signature: 0x43525643, id: GlobalAction.toggle.rawValue)
            #expect(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &identifier) == noErr)
            #expect(SendEventToEventTarget(event, GetEventDispatcherTarget()) == noErr)
        }
        #expect(received == [true, false])
    }
    @Test func rollbackPreservesWorkingShortcuts() throws {
        let registrar = RegistrarDouble(); let manager = HotKeyConfigurationManager(registrar: registrar)
        let original = ShortcutConfiguration(); try manager.apply(original)
        var changed = original; changed.toggle.key = .f12; registrar.reject = changed.toggle
        #expect(throws: HotKeyFailure.self) { try manager.apply(changed) }
        #expect(manager.active == original); #expect(registrar.current.count == 1)
        manager.stop(); #expect(registrar.current.isEmpty)
    }
    @Test func invalidConfigurationDoesNotDestroyCurrentRegistration() throws {
        let registrar = RegistrarDouble(); let manager = HotKeyConfigurationManager(registrar: registrar)
        let original = ShortcutConfiguration(); try manager.apply(original)
        var bad = original; bad.toggle = GlobalShortcut(control: false, option: false, shift: true)
        #expect(throws: HotKeyFailure.self) { try manager.apply(bad) }
        #expect(manager.active == original)
    }
    @Test func toggleStartsAndStopsOnlyOnSeparatePresses() {
        var gesture = ShortcutGesture()
        #expect(gesture.event(pressed: true, state: .idle) == .start)
        #expect(gesture.event(pressed: true, state: .recording) == .none)
        #expect(gesture.event(pressed: false, state: .recording) == .none)
        #expect(gesture.event(pressed: true, state: .recording) == .stop)
        #expect(gesture.event(pressed: false, state: .transcribing) == .none)
    }
    @Test func releaseNeverCancelsPreparationAndNextPressCanCancel() {
        var gesture = ShortcutGesture()
        #expect(gesture.event(pressed: true, state: .idle) == .start)
        #expect(gesture.event(pressed: false, state: .preparing) == .none)
        #expect(gesture.event(pressed: true, state: .preparing) == .cancel)
        gesture.reset()
        #expect(gesture.event(pressed: true, state: .completed) == .start)
    }
    @Test func busyPressDoesNotStartAnotherRecording() {
        var gesture = ShortcutGesture()
        #expect(gesture.event(pressed: true, state: .transcribing) == .none)
        #expect(gesture.event(pressed: false, state: .transcribing) == .none)
        #expect(gesture.event(pressed: true, state: .completed) == .start)
    }
    @Test func legacyPreferencesPreserveCustomToggleAndEncodeOnlyToggle() throws {
        let custom = GlobalShortcut(key: .f9, control: false, option: true, command: true)
        let legacy = try JSONSerialization.data(withJSONObject: [
            "toggle": JSONSerialization.jsonObject(with: JSONEncoder().encode(custom)),
            "hold": JSONSerialization.jsonObject(with: JSONEncoder().encode(GlobalShortcut(shift: true)))])
        let decoded = try JSONDecoder().decode(ShortcutConfiguration.self, from: legacy)
        #expect(decoded.toggle == custom)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        #expect(Set(encoded.keys) == ["toggle"])
        #expect(GlobalAction(rawValue: 2) == nil)
    }
    @Test func onlyToggleIsRegisteredAndReapplyingIsIdempotent() throws {
        let registrar = RegistrarDouble(); let manager = HotKeyConfigurationManager(registrar: registrar)
        try manager.apply(ShortcutConfiguration()); try manager.apply(ShortcutConfiguration())
        #expect(registrar.current == [GlobalAction.toggle.rawValue: GlobalShortcut()])
        manager.stop(); #expect(registrar.current.isEmpty)
    }
}
