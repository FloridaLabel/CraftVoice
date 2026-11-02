import Foundation

public enum InsertionOutcome: Equatable, Sendable {
    case inserted, payloadPresent, interrupted, unsupportedPayload, blocked, inputUnverified, writeRejected, acceptedUnverified, uncertain, clipboardChanged, clipboardUnrestored
    public var message: String {
        switch self {
        case .inserted: "Text eingefügt."
        case .payloadPresent: "Diktat vollständig im Zieltextfeld nachgewiesen. Vorheriger Feldwert abweichend; kein erneuter Versuch."
        case .interrupted: "Eingabeversand unterbrochen. Der Text könnte unvollständig sein; kein automatischer zweiter Versuch."
        case .unsupportedPayload: "Dieser Text kann in diesem Feld nicht sicher eingefügt werden. Er bleibt in CraftVoice."
        case .blocked: "Das ursprüngliche Textfeld ist nicht mehr sicher erreichbar. Der Text bleibt in CraftVoice."
        case .inputUnverified: "Texteingabe gesendet, aber nicht verifizierbar. Prüfe die Zielanwendung; CraftVoice versucht es nicht erneut."
        case .writeRejected: "Einfügen fehlgeschlagen: Die Zielanwendung hat die AX-Schreiboperation abgewiesen. Der Text bleibt in CraftVoice; kein erneuter Versuch."
        case .acceptedUnverified: "AX-Schreiboperation angenommen, Texteingabe nicht verifizierbar. Prüfe die Zielanwendung; CraftVoice versucht es nicht erneut."
        case .uncertain: "AX-Schreibstatus unklar. Eine Texteingabe ist möglich; prüfe die Zielanwendung. CraftVoice versucht es nicht erneut."
        case .clipboardChanged: "Die Zwischenablage wurde inzwischen geändert. Der Text bleibt in CraftVoice."
        case .clipboardUnrestored: "Einfügen nicht bestätigt. Die Zwischenablage enthält möglicherweise den Diktattext; prüfe die Zielanwendung."
        }
    }
}

/// Must be consumed before the first system mutation; no automatic retry or fallback after dispatch.
public struct InsertionTicket: Sendable {
    public let id: UUID
    public private(set) var consumed = false
    public private(set) var invalidated = false
    public init(id: UUID = UUID()) { self.id = id }
    public mutating func invalidate() { invalidated = true }
    public mutating func consume(focusMatches: Bool, allowed: Bool, secureInput: Bool, text: String) -> Bool {
        guard !consumed, !invalidated, focusMatches, allowed, !secureInput,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        consumed = true
        return true
    }
}

public enum ExpectedInsertion {
    /// AX ranges use UTF-16, not Swift Character offsets. Reject invalid/split-surrogate ranges.
    public static func replacing(value: String, location: Int, length: Int, text: String) -> String? {
        let units = Array(value.utf16)
        func boundary(_ offset: Int) -> Bool {
            guard offset > 0 && offset < units.count else { return true }
            return !(0xD800...0xDBFF).contains(units[offset - 1]) || !(0xDC00...0xDFFF).contains(units[offset])
        }
        guard location >= 0, length >= 0, location <= value.utf16.count,
              length <= value.utf16.count - location,
              boundary(location), boundary(location + length),
              let range = Range(NSRange(location: location, length: length), in: value) else { return nil }
        var result = value
        result.replaceSubrange(range, with: text)
        return result
    }
}
