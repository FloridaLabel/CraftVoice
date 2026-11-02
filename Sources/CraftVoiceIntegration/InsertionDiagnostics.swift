import ApplicationServices

/// A successful AX request is not evidence that the editor changed its contents.
public enum DirectWriteResult: Equatable, Sendable {
    case blocked, accepted, rejected(Int32), indeterminate(Int32)
    public static func classify(_ error: AXError) -> Self {
        switch error {
        case .success: .accepted
        case .attributeUnsupported, .actionUnsupported, .notImplemented, .illegalArgument,
             .invalidUIElement, .apiDisabled: .rejected(error.rawValue)
        default: .indeterminate(error.rawValue)
        }
    }
}
public enum InsertionReadback: Equatable, Sendable {
    case confirmed, payloadPresent, unchanged, different, unreadable(Int32), targetLost
    public static func compare(value: String?, original: String, expected: String, inserted: String? = nil) -> Self {
        guard let value else { return .unreadable(AXError.noValue.rawValue) }
        if value == expected { return .confirmed }
        if value == original { return .unchanged }
        if let inserted, value == inserted { return .payloadPresent }
        return .different
    }
}
