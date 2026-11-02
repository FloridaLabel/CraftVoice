import Foundation

/// Pure session policy. No keyboard, clipboard, permission or network side effects.
public struct DictationSession: Sendable {
    public enum State: Equatable, Sendable { case idle, recording, transcribing, ready, completed, cancelled }
    public private(set) var state: State = .idle
    public private(set) var targetPID: Int32?
    public private(set) var focusToken: UUID?

    public init() {}
    @discardableResult public mutating func start(targetPID: Int32, focusToken: UUID) -> Bool {
        guard state == .idle, targetPID > 0 else { return false }
        self.targetPID = targetPID
        self.focusToken = focusToken
        state = .recording
        return true
    }
    @discardableResult public mutating func release() -> Bool {
        guard state == .recording else { return false }
        state = .transcribing
        return true
    }
    @discardableResult public mutating func finishTranscription() -> Bool {
        guard state == .transcribing else { return false }
        state = .ready
        return true
    }
    public mutating func cancel() {
        guard state != .completed else { return }
        state = .cancelled
    }
    /// Consume once BEFORE dispatch. Unknown focus or permissions must fail closed.
    @discardableResult public mutating func consumeInsertion(
        currentPID: Int32?, currentFocusToken: UUID?, accessibilityGranted: Bool,
        postingGranted: Bool, secureInput: Bool, text: String
    ) -> Bool {
        guard state == .ready, accessibilityGranted, postingGranted, !secureInput,
              currentPID == targetPID, currentFocusToken == focusToken,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        state = .completed
        return true
    }
}

public enum ClipboardPolicy {
    /// This is necessary, not sufficient: the future adapter must snapshot every supported type
    /// and wait for verified paste consumption. A fixed delay cannot prove consumption.
    public static func mayRestore(ownedChangeCount: Int, currentChangeCount: Int) -> Bool {
        ownedChangeCount == currentChangeCount
    }
}
