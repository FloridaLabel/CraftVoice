import Foundation

/// No application, hostname or framework enters transport selection.
public enum InputPolicy {
    public static func editable(role: String, selectedTextWritable: Bool, valueWritable: Bool, editable: Bool, selectionWritable: Bool) -> Bool {
        switch role {
        case "AXTextField", "AXTextArea": selectedTextWritable || valueWritable || editable
        case "AXComboBox": selectedTextWritable || editable || (valueWritable && selectionWritable)
        default: false
        }
    }
    public static func containsLineBreak(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.newlines.contains($0) }
    }
    public static func safeLiteral(_ text: String, acceptsNewlines: Bool) -> Bool {
        !text.unicodeScalars.contains { scalar in
            if CharacterSet.newlines.contains(scalar) { return !acceptsNewlines }
            return scalar.value < 32 || (127...159).contains(scalar.value)
        }
    }
    public static func sameDocument(_ original: String?, _ current: String?) -> Bool { original == current }
}
