import Testing
@testable import CraftVoiceCore

struct DeliveryStatusTests {
    @Test func resultRetainsCaptureFailureRatherThanReportingLocalSuccess() {
        let status = DeliveryStatus.unavailable("Bedienungshilfen fehlen.")
        #expect(status.retainedResultMessage.contains("Bedienungshilfen fehlen."))
        #expect(!status.retainedResultMessage.contains("Lokal im Diktatfenster gestartet"))
    }
    @Test func localStartAndDisabledInsertionRemainDistinguishable() {
        #expect(DeliveryStatus.local.retainedResultMessage.contains("global"))
        #expect(DeliveryStatus.disabled.retainedResultMessage.contains("deaktiviert"))
        #expect(DeliveryStatus.local != DeliveryStatus.disabled)
    }
}
