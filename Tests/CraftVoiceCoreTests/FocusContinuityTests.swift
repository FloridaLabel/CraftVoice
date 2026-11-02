import Testing
@testable import CraftVoiceCore

struct FocusContinuityTests {
    @Test func redundantNotificationsDoNotDiscardAnUnchangedTarget() {
        var guardState = FocusContinuity()
        for _ in 0..<5 { guardState.observe(matchesOriginal: true) }
        #expect(!guardState.invalidated)
    }
    @Test func realChangeIsStickyEvenAfterReturningToOriginalField() {
        var guardState = FocusContinuity()
        guardState.observe(matchesOriginal: false)
        guardState.observe(matchesOriginal: true)
        #expect(guardState.invalidated)
    }
    @Test func destroyedElementCannotBeReused() {
        var guardState = FocusContinuity()
        guardState.observe(matchesOriginal: true, destroyed: true)
        #expect(guardState.invalidated)
    }
}
