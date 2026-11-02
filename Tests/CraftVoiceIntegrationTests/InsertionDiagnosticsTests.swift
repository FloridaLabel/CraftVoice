import Testing
import ApplicationServices
import CraftVoiceCore
@testable import CraftVoiceIntegration

struct InsertionDiagnosticsTests {
    @Test func axRequestResultIsSeparateFromTextVerification() {
        #expect(DirectWriteResult.classify(.success) == .accepted)
        #expect(DirectWriteResult.classify(.attributeUnsupported) == .rejected(AXError.attributeUnsupported.rawValue))
        #expect(DirectWriteResult.classify(.cannotComplete) == .indeterminate(AXError.cannotComplete.rawValue))
        #expect(DirectWriteResult.classify(.failure) == .indeterminate(AXError.failure.rawValue))
    }
    @Test func unchangedAndUnreadableAreNotProofOfFailure() {
        #expect(InsertionReadback.compare(value: "vorher", original: "vorher", expected: "nachher") == .unchanged)
        #expect(InsertionReadback.compare(value: nil, original: "vorher", expected: "nachher") == .unreadable(AXError.noValue.rawValue))
        #expect(InsertionReadback.compare(value: "anders", original: "vorher", expected: "nachher") == .different)
        #expect(InsertionReadback.compare(value: "nachher", original: "vorher", expected: "nachher") == .confirmed)
    }
    @Test func fullPayloadIsProvedWithoutGuessingPlaceholderOrClaimingOriginalState() {
        #expect(InsertionReadback.compare(value: "Diktat", original: "ChatGPT fragen\n", expected: "DiktatChatGPT fragen\n", inserted: "Diktat") == .payloadPresent)
        #expect(InsertionReadback.compare(value: "Dikt", original: "ChatGPT fragen\n", expected: "DiktatChatGPT fragen\n", inserted: "Diktat") == .different)
        #expect(InsertionReadback.compare(value: "DiktatDiktat", original: "ChatGPT fragen\n", expected: "DiktatChatGPT fragen\n", inserted: "Diktat") == .different)
        #expect(InsertionReadback.compare(value: "Diktat", original: "Diktat", expected: "DiktatDiktat", inserted: "Diktat") == .unchanged)
    }
    @Test func userMessagesSeparateRejectedFromUnverified() {
        #expect(InsertionOutcome.writeRejected.message.contains("fehlgeschlagen"))
        #expect(InsertionOutcome.acceptedUnverified.message.contains("nicht verifizierbar"))
        #expect(!InsertionOutcome.acceptedUnverified.message.contains("fehlgeschlagen"))
    }
}
