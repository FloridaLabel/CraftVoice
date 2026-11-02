import Testing
@testable import CraftVoiceIntegration

struct WebEditorContextTests {
    func search(roles: [Int: String], parents: [Int: Int], depth: Int = 32) -> Int? {
        AXAncestorSearch.nearestWebArea(from: 0, maximumDepth: depth, role: { roles[$0] }, parent: { parents[$0] }, equal: ==)
    }
    @Test func nearestWebContextIsCapturedWithoutCrossingIntoOtherFrames() {
        #expect(search(roles: [0:"AXTextArea", 1:"AXGroup", 2:"AXWebArea", 3:"AXWebArea"], parents: [0:1,1:2,2:3]) == 2)
    }
    @Test func nativeWindowIsNeverClassifiedByAnUnrelatedWebArea() {
        #expect(search(roles: [0:"AXTextField",1:"AXWindow",2:"AXWebArea"], parents: [0:1,1:2]) == nil)
    }
    @Test func missingRolesCyclesAndTruncatedChainsDoNotEnableUnicode() {
        #expect(search(roles: [0:"AXTextArea",2:"AXWebArea"], parents: [0:1,1:2]) == nil)
        #expect(search(roles: [0:"AXTextArea",1:"AXGroup"], parents: [0:1,1:0]) == nil)
        #expect(search(roles: [0:"AXTextArea",1:"AXWebArea"], parents: [0:1], depth: 1) == nil)
    }
}
