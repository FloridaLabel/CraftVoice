import AppKit
import CoreGraphics

public enum UnicodeDispatchResult: Equatable, Sendable { case notSent, posted, partial }
public enum UnicodeInputPayload {
    /// Keep Quartz payloads small, preserving UTF-16 surrogate pairs. Never send
    /// Return/Enter key codes, shortcuts, or clipboard operations.
    public static func chunks(_ text: String) -> [[UniChar]]? {
        guard InputPolicy.safeLiteral(text, acceptsNewlines: false) else { return nil }
        let units = Array(text.utf16)
        var result: [[UniChar]] = []
        var offset = 0
        while offset < units.count {
            var end = min(offset + 20, units.count)
            if end < units.count, (0xD800...0xDBFF).contains(units[end - 1]) { end -= 1 }
            result.append(Array(units[offset..<end])); offset = end
        }
        return result
    }
    public static func payload(_ event: CGEvent) -> [UniChar] {
        var length = 0
        var units = [UniChar](repeating: 0, count: 32)
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
        return Array(units.prefix(length))
    }
    public static func events(_ text: String) -> [(CGEvent, CGEvent)]? {
        guard let chunks = chunks(text), !chunks.isEmpty,
              let source = CGEventSource(stateID: .privateState) else { return nil }
        var result: [(CGEvent, CGEvent)] = []
        // Prepare the complete batch before dispatching even its first event.
        for chunk in chunks {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return nil }
            down.flags = []; up.flags = []
            chunk.withUnsafeBufferPointer { buffer in
                down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress!)
                up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress!)
            }
            result.append((down, up))
        }
        return result
    }
}
