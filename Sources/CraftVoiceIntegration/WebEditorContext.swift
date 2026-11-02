import AppKit
import ApplicationServices

public enum AXAncestorSearch {
    /// Walk only ancestors of the captured field, never search another field or
    /// application. Missing roles, cycles, depth exhaustion and native roots fail closed.
    public static func nearestWebArea<Node>(from field: Node, maximumDepth: Int = 32,
        role: (Node) -> String?, parent: (Node) -> Node?, equal: (Node, Node) -> Bool) -> Node? {
        var node: Node? = field
        var visited: [Node] = []
        for _ in 0..<max(0, maximumDepth) {
            guard let current = node, !visited.contains(where: { equal($0, current) }),
                  let currentRole = role(current) else { return nil }
            if currentRole == "AXWebArea" { return current }
            if currentRole == "AXWindow" || currentRole == "AXApplication" { return nil }
            visited.append(current)
            node = parent(current)
        }
        return nil
    }
}

@MainActor struct WebEditorContext {
    let area: AXUIElement
    let document: String?
    static func capture(field: AXUIElement) -> Self? {
        guard let area = AXAncestorSearch.nearestWebArea(from: field,
            role: { AXRead.value($0, kAXRoleAttribute) as? String },
            parent: { AXRead.element($0, kAXParentAttribute) }, equal: { CFEqual($0, $1) }) else { return nil }
        var fieldPID: pid_t = 0, areaPID: pid_t = 0
        guard AXUIElementGetPid(field, &fieldPID) == .success,
              AXUIElementGetPid(area, &areaPID) == .success, fieldPID == areaPID else { return nil }
        let raw = AXRead.value(area, kAXURLAttribute)
        let document = (raw as? URL)?.absoluteString ?? (raw as? String)
        return Self(area: area, document: document)
    }
    func matches(field: AXUIElement) -> Bool {
        guard let current = Self.capture(field: field) else { return false }
        return CFEqual(area, current.area) && document == current.document
    }
}
