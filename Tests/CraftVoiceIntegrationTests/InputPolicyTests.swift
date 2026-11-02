import Testing
@testable import CraftVoiceIntegration

struct InputPolicyTests {
    @Test(arguments: ["AXTextField", "AXTextArea", "AXComboBox"])
    func advertisedTextSelectionWriterProvesEditableTextRole(_ role: String) {
        #expect(InputPolicy.editable(role: role, selectedTextWritable: true, valueWritable: false, editable: false, selectionWritable: false))
    }
    @Test func editableSearchComboboxIsNotConfusedWithSelectOnlyControl() {
        #expect(InputPolicy.editable(role: "AXComboBox", selectedTextWritable: false, valueWritable: true, editable: false, selectionWritable: true))
        #expect(!InputPolicy.editable(role: "AXComboBox", selectedTextWritable: false, valueWritable: true, editable: false, selectionWritable: false))
        #expect(!InputPolicy.editable(role: "AXButton", selectedTextWritable: true, valueWritable: true, editable: true, selectionWritable: true))
    }
    @Test func literalNewlinesNeverBecomeKeyboardCommandsOrSingleLineInput() {
        for text in ["eins\nzwei", "eins\r\nzwei", "eins\u{2028}zwei"] {
            #expect(InputPolicy.containsLineBreak(text))
            #expect(!InputPolicy.safeLiteral(text, acceptsNewlines: false))
            #expect(InputPolicy.safeLiteral(text, acceptsNewlines: true))
            #expect(UnicodeInputPayload.events(text) == nil)
        }
        #expect(!InputPolicy.safeLiteral("tab\tfield", acceptsNewlines: true))
        #expect(!InputPolicy.safeLiteral("escape\u{1b}", acceptsNewlines: true))
    }
    @Test func optionalContextMustRemainExactlyTheSame() {
        #expect(InputPolicy.sameDocument(nil, nil))
        #expect(!InputPolicy.sameDocument(nil, "new"))
        #expect(!InputPolicy.sameDocument("old", nil))
        #expect(!InputPolicy.sameDocument("old", "new"))
    }
}
