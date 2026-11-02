import AppKit
import ApplicationServices
import Carbon
import OSLog
import CraftVoiceCore

@MainActor public protocol InsertionTargetAccess: AnyObject {
    var originalValue: String { get }
    var insertionRange: NSRange { get }
    var direct: Bool { get }
    var acceptsNewlines: Bool { get }
    var allowed: Bool { get }
    var secureInput: Bool { get }
    var canPost: Bool { get }
    func matchesOriginal() -> Bool
    func matchesIdentity() -> Bool
    func observeInsertion(expected: String, inserted: String) -> InsertionReadback
    func writeSelectedText(_ text: String) -> DirectWriteResult
    func postPaste() -> Bool
    /// notSent MUST mean zero posted keyboard events. Partial is never retryable.
    func postUnicode(_ text: String) -> UnicodeDispatchResult
}

@MainActor public final class TextInsertion {
    public private(set) var pendingClipboard: ClipboardTransaction?
    private let clipboard: any ClipboardAccess
    private static let log = Logger(subsystem: "app.craftvoice.desktop", category: "Integration")
    private let modifiersReleased: @MainActor () -> Bool
    public init(clipboard: any ClipboardAccess = SystemClipboard(),
                modifiersReleased: @escaping @MainActor () -> Bool = { NSEvent.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty }) {
        self.clipboard = clipboard; self.modifiersReleased = modifiersReleased
    }
    public func restoreClipboard() -> Bool {
        defer { pendingClipboard = nil }
        return pendingClipboard?.restore() ?? false
    }
    private func safe(_ target: any InsertionTargetAccess) -> Bool {
        let allowed = target.allowed, secure = target.secureInput, focus = target.matchesOriginal()
        let cancelled = Task.isCancelled
        if !allowed || secure || !focus || cancelled {
            Self.log.notice("stage=guard focus=\(focus) allowed=\(allowed) secure=\(secure) cancelled=\(cancelled)")
        }
        return !cancelled && allowed && !secure && focus
    }
    private func releaseModifiers() async -> Bool {
        for _ in 0..<50 {
            if Task.isCancelled { return false }
            if modifiersReleased() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }
    public func insert(_ text: String, target: any InsertionTargetAccess, ticket: inout InsertionTicket, allowClipboard: Bool) async -> InsertionOutcome {
        let session = ticket.id
        guard pendingClipboard == nil, safe(target),
              let expected = ExpectedInsertion.replacing(value: target.originalValue,
                  location: target.insertionRange.location, length: target.insertionRange.length, text: text) else { return .blocked }
        guard InputPolicy.safeLiteral(text, acceptsNewlines: target.acceptsNewlines) else { return .unsupportedPayload }
        LocalDiagnosticCapture.text(text, name: "before-send.txt")
        LocalDiagnosticCapture.text(target.originalValue, name: "original-field.txt")
        LocalDiagnosticCapture.text(expected, name: "expected-field.txt")
        guard ticket.consume(focusMatches: target.matchesOriginal(), allowed: target.allowed,
            secureInput: target.secureInput, text: text) else { return .blocked }
        Self.log.notice("session=\(session.uuidString, privacy: .public) stage=preflight safe=true keyboardAvailable=\(target.canPost)")
        let literal = InputPolicy.containsLineBreak(text)
        if !literal && target.canPost {
            guard await releaseModifiers(), safe(target) else { return .blocked }
            let result = target.postUnicode(text)
            Self.log.notice("session=\(session.uuidString, privacy: .public) stage=unicode-write result=\(String(describing: result), privacy: .public)")
            switch result {
            case .posted:
                return outcome(await confirm(target: target, expected: expected, inserted: text, session: session), otherwise: .inputUnverified)
            case .partial:
                _ = await confirm(target: target, expected: expected, inserted: text, session: session)
                return .interrupted
            case .notSent:
                // The ONLY automatic cross-transport fallback: no text event left
                // the adapter. Unchanged AX content alone is NEVER this proof.
                Self.log.notice("session=\(session.uuidString, privacy: .public) stage=fallback reason=zeroEventsPosted")
                guard safe(target) else { return .blocked }
            }
        }
        // Literal multiline paste is selected before AX if explicitly enabled.
        if literal && allowClipboard && target.canPost {
            return await paste(text, expected: expected, target: target, session: session)
        }
        if target.direct {
            guard safe(target) else { return .blocked }
            let result = target.writeSelectedText(text)
            Self.log.notice("session=\(session.uuidString, privacy: .public) stage=ax-write result=\(String(describing: result), privacy: .public)")
            switch result {
            case .blocked: return .blocked // No call, but the adapter lost a safety precondition.
            case .rejected: return .writeRejected
            case .indeterminate:
                return outcome(await confirm(target: target, expected: expected, inserted: text, session: session), otherwise: .uncertain)
            case .accepted:
                return outcome(await confirm(target: target, expected: expected, inserted: text, session: session), otherwise: .acceptedUnverified)
            }
        }
        guard allowClipboard, target.canPost else { return literal ? .unsupportedPayload : .blocked }
        return await paste(text, expected: expected, target: target, session: session)
    }
    private func paste(_ text: String, expected: String, target: any InsertionTargetAccess, session: UUID) async -> InsertionOutcome {
        guard await releaseModifiers(), safe(target) else { return .blocked }
        guard let transaction = ClipboardTransaction.begin(text: text, clipboard: clipboard) else { return .clipboardChanged }
        guard safe(target) else { _ = transaction.restore(); return .blocked }
        guard transaction.stillOwned else { return .clipboardChanged }
        guard target.postPaste() else { _ = transaction.restore(); return .blocked }
        Self.log.notice("session=\(session.uuidString, privacy: .public) stage=clipboard-write posted=true")
        if await confirm(target: target, expected: expected, inserted: text, session: session) == .confirmed {
            _ = transaction.restore()
            return .inserted
        }
        pendingClipboard = transaction
        return .clipboardUnrestored
    }
    private func outcome(_ observation: InsertionReadback, otherwise fallback: InsertionOutcome) -> InsertionOutcome {
        switch observation {
        case .confirmed: .inserted
        case .payloadPresent: .payloadPresent
        default: fallback
        }
    }
    private func confirm(target: any InsertionTargetAccess, expected: String, inserted: String, session: UUID) async -> InsertionReadback {
        var last: InsertionReadback?
        for sample in 0..<40 {
            let observation = target.observeInsertion(expected: expected, inserted: inserted)
            if observation != last || sample == 39 {
                let focused = target.matchesIdentity()
                Self.log.notice("session=\(session.uuidString, privacy: .public) stage=readback sample=\(sample) result=\(String(describing: observation), privacy: .public) originalFocus=\(focused)")
                last = observation
            }
            if observation == .confirmed || observation == .payloadPresent { return observation }
            if observation == .targetLost || Task.isCancelled { return observation }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return last ?? .targetLost
    }
}
