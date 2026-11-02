import Foundation
import Testing
@testable import CraftVoiceCore

struct LocalDiagnosticCaptureTests {
    @Test func normalLaunchDoesNotEnableContentCapture() {
        if ProcessInfo.processInfo.environment["CRAFTVOICE_DIAGNOSTICS_DIR"] == nil {
            #expect(LocalDiagnosticCapture.latestFolder == nil)
            #expect(LocalDiagnosticCapture.folder(for: URL(fileURLWithPath: "/tmp/CraftVoice-test/recording.wav")) == nil)
        }
    }
    @Test func explicitlySelectedTestArtifactPreservesTextAndPrivatePermissions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CraftVoice-diagnostic-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: folder) }
        let text = "Start. Grüße 😀. Schlussmarke drei."
        LocalDiagnosticCapture.text(text, name: "test.txt", folder: folder)
        let file = folder.appendingPathComponent("test.txt")
        #expect(try String(contentsOf: file, encoding: .utf8) == text)
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
    }
}
