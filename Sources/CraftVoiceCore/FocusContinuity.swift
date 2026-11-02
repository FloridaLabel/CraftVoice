/// AX notifications announce possible changes; they do not prove a different target.
/// Once a real change is observed, returning to the original field never rearms it.
public struct FocusContinuity: Sendable {
    public private(set) var invalidated = false
    public init() {}
    public mutating func observe(matchesOriginal: Bool, destroyed: Bool = false) {
        if destroyed || !matchesOriginal { invalidated = true }
    }
}
