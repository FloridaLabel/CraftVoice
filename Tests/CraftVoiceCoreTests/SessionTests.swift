import Foundation
import Testing
@testable import CraftVoiceCore

private let focus = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private func ready() -> DictationSession {
    var s = DictationSession()
    let result7 = s.start(targetPID: 42, focusToken: focus)
    #expect(result7)
    let result8 = !s.start(targetPID: 42, focusToken: focus)
    #expect(result8)
    let result9 = s.release()
    #expect(result9)
    let result10 = !s.release()
    #expect(result10)
    let result11 = s.finishTranscription()
    #expect(result11)
    return s
}
@Test func insertsOnce() {
    var s = ready()
    let result16 = s.consumeInsertion(currentPID: 42, currentFocusToken: focus, accessibilityGranted: true, postingGranted: true, secureInput: false, text: "Grüße, Straße, 3,5 mm.")
    #expect(result16)
    let result17 = !s.consumeInsertion(currentPID: 42, currentFocusToken: focus, accessibilityGranted: true, postingGranted: true, secureInput: false, text: "Doppelt")
    #expect(result17)
}
@Test(arguments: [0, 1, 2, 3, 4, 5, 6]) func rejectsUnsafeInsertion(_ scenario: Int) {
    var s = ready()
    let result = s.consumeInsertion(currentPID: scenario == 0 ? 99 : (scenario == 1 ? nil : 42),
        currentFocusToken: scenario == 2 ? UUID() : focus,
        accessibilityGranted: scenario != 3, postingGranted: scenario != 4,
        secureInput: scenario == 5, text: scenario == 6 ? " \n" : "Hallo")
    #expect(!result)
    #expect(s.state == .ready)
}
@Test func cancellationRejectsLateResults() {
    var s = ready()
    s.cancel()
    let result31 = !s.finishTranscription()
    #expect(result31)
    let result32 = !s.consumeInsertion(currentPID: 42, currentFocusToken: focus, accessibilityGranted: true, postingGranted: true, secureInput: false, text: "Zu spät")
    #expect(result32)
}
@Test func invalidOrderAndMissingTarget() {
    var s = DictationSession()
    let result36 = !s.release()
    #expect(result36)
    let result37 = !s.finishTranscription()
    #expect(result37)
    let result38 = !s.start(targetPID: 0, focusToken: focus)
    #expect(result38)
}
@Test func clipboardOwnership() {
    #expect(ClipboardPolicy.mayRestore(ownedChangeCount: 10, currentChangeCount: 10))
    #expect(!ClipboardPolicy.mayRestore(ownedChangeCount: 10, currentChangeCount: 11))
}

@Test func permanentDefaultModelLocation() {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    #expect(LocalModelLocation.defaultFolder(home: home).path == "/Users/example/Library/Application Support/CraftVoice/Models/large-v3-turbo")
}
