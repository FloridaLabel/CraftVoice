import Foundation

public enum ShortcutKey: String, CaseIterable, Codable, Sendable {
    case space, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case f6, f7, f8, f9, f10, f11, f12
    public var code: UInt32 {
        switch self {
        case .space: 49
        case .a: 0; case .b: 11; case .c: 8; case .d: 2; case .e: 14; case .f: 3
        case .g: 5; case .h: 4; case .i: 34; case .j: 38; case .k: 40; case .l: 37
        case .m: 46; case .n: 45; case .o: 31; case .p: 35; case .q: 12; case .r: 15
        case .s: 1; case .t: 17; case .u: 32; case .v: 9; case .w: 13; case .x: 7
        case .y: 6; case .z: 16
        case .f6: 97; case .f7: 98; case .f8: 100; case .f9: 101; case .f10: 109; case .f11: 103; case .f12: 111
        }
    }
    public var title: String { self == .space ? "Leertaste" : rawValue.uppercased() }
}
public struct GlobalShortcut: Codable, Equatable, Sendable {
    public var key: ShortcutKey
    public var control: Bool
    public var option: Bool
    public var command: Bool
    public var shift: Bool
    public init(key: ShortcutKey = .space, control: Bool = true, option: Bool = true, command: Bool = false, shift: Bool = false) {
        self.key = key; self.control = control; self.option = option; self.command = command; self.shift = shift
    }
    public var valid: Bool { control || option || command }
    public var title: String { (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key.title }
    public var carbonModifiers: UInt32 { (control ? 4096 : 0) | (option ? 2048 : 0) | (command ? 256 : 0) | (shift ? 512 : 0) }
}
public struct ShortcutConfiguration: Codable, Equatable, Sendable {
    public var toggle: GlobalShortcut
    // Codable ignores unknown legacy keys, preserving the stored toggle unchanged.
    public init(toggle: GlobalShortcut = GlobalShortcut()) { self.toggle = toggle }
    public var valid: Bool { toggle.valid }
}
public enum GlobalAction: UInt32, Sendable { case toggle = 1 }
public enum DictationCommand: Equatable, Sendable { case start, stop, cancel, none }

/// Releases only rearm repeat suppression; they never stop a recording.
public struct ShortcutGesture: Sendable {
    private var pressed = false
    public init() {}
    public mutating func event(pressed down: Bool, state: DictationController.State) -> DictationCommand {
        if !down { pressed = false; return .none }
        guard !pressed else { return .none }
        pressed = true
        if state == .preparing { return .cancel }
        if state == .recording { return .stop }
        guard state != .transcribing else { return .none }
        return .start
    }
    public mutating func reset() { pressed = false }
}
