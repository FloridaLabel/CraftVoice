import Foundation
import Testing
@testable import CraftVoiceCore

private func fixture() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("CraftVoice-tests-\(UUID())")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for name in LocalModelAssets.modelNames {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("\(name).mlmodelc"), withIntermediateDirectories: false)
    }
    // Structural fixtures only: not language models and never passed to Core ML.
    for name in ["tokenizer.json", "tokenizer_config.json"] {
        try Data("{}".utf8).write(to: dir.appendingPathComponent(name))
    }
    return dir
}

@MainActor private final class RecorderDouble: AudioRecording {
    var onCompletion: (@MainActor @Sendable (Bool) -> Void)?
    var starts = 0
    var cancels = 0
    var failure: SpeechFailure?
    var audio: RecordedAudio?
    func start() async throws {
        starts += 1
        try Task.checkCancellation()
        if let failure { throw failure }
    }
    func stop() throws -> RecordedAudio {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("CraftVoice-audio-test-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        let file = dir.appendingPathComponent("test.wav")
        try Data(repeating: 0, count: 100).write(to: file)
        let result = RecordedAudio(file: file, directory: dir)
        audio = result
        return result
    }
    func cancel() { cancels += 1 }
}
private actor EngineDouble: SpeechTranscribing {
    var prepareCalls = 0
    var transcribeCalls = 0
    var failure: SpeechFailure?
    var output = "Grüße aus Köln: 12,5 Millimeter."
    var waitInPrepare = false
    var waitInTranscription = false
    var continuation: CheckedContinuation<Void, Never>?
    func configure(failure: SpeechFailure? = nil, output: String = "Grüße aus Köln: 12,5 Millimeter.", waitPrepare: Bool = false, waitTranscribe: Bool = false) {
        self.failure = failure; self.output = output
        waitInPrepare = waitPrepare; waitInTranscription = waitTranscribe
    }
    func prepare(model: URL) async throws {
        prepareCalls += 1
        if waitInPrepare { await withCheckedContinuation { continuation = $0 } }
        if failure == .invalidAssets { throw SpeechFailure.invalidAssets }
    }
    func transcribe(file: URL) async throws -> String {
        transcribeCalls += 1
        if waitInTranscription { await withCheckedContinuation { continuation = $0 } }
        if let failure { throw failure }
        return output
    }
    func isWaiting() -> Bool { continuation != nil }
    func resume() { continuation?.resume(); continuation = nil }
}
private func waitForGate(_ engine: EngineDouble) async throws {
    for _ in 0..<10_000 { if await engine.isWaiting() { return }; await Task.yield() }
    throw SpeechFailure.engineBusy
}

@Suite @MainActor struct DictationTests {
    @Test func recordsStopsAndDeletesTemporaryAudio() async throws {
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        let rec = RecorderDouble(); let engine = EngineDouble()
        let controller = DictationController(recorder: rec, engine: engine)
        await controller.start(model: model)?.value
        #expect(controller.state == .recording)
        #expect(controller.start(model: model) == nil)
        await controller.stop()?.value
        #expect(controller.state == .completed)
        #expect(controller.text == "Grüße aus Köln: 12,5 Millimeter.")
        #expect(controller.stop() == nil)
        #expect(!FileManager.default.fileExists(atPath: rec.audio!.file.path))
        #expect(await engine.transcribeCalls == 1)
    }
    @Test func missingModelsNeverRequestMicrophoneOrStartEngine() async {
        let rec = RecorderDouble(); let engine = EngineDouble()
        let controller = DictationController(recorder: rec, engine: engine)
        await controller.start(model: URL(fileURLWithPath: "/tmp/CraftVoice-missing-\(UUID())"))?.value
        #expect(controller.state == .failed)
        #expect(controller.errorMessage?.contains("Modelldatei fehlt") == true)
        #expect(rec.starts == 0)
        #expect(await engine.prepareCalls == 0)
    }
    @Test(arguments: [SpeechFailure.permissionDenied, .recordingFailed, .noMicrophone])
    func recordingFailure(_ failure: SpeechFailure) async throws {
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        let rec = RecorderDouble(); rec.failure = failure
        let controller = DictationController(recorder: rec, engine: EngineDouble())
        await controller.start(model: model)?.value
        #expect(controller.state == .failed)
        #expect(controller.errorMessage == failure.errorDescription)
        #expect(rec.cancels > 0)
    }
    @Test func cancellationDuringModelLoadingPreventsRecording() async throws {
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        let rec = RecorderDouble(); let engine = EngineDouble()
        await engine.configure(waitPrepare: true)
        let controller = DictationController(recorder: rec, engine: engine)
        let task = controller.start(model: model)
        try await waitForGate(engine)
        controller.cancel()
        await engine.resume(); await task?.value
        #expect(controller.state == .cancelled)
        #expect(rec.starts == 0)
    }
    @Test func cancellationDiscardsLateTranscriptionAndDeletesAudio() async throws {
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        let rec = RecorderDouble(); let engine = EngineDouble()
        await engine.configure(waitTranscribe: true)
        let controller = DictationController(recorder: rec, engine: engine)
        await controller.start(model: model)?.value
        let task = controller.stop()
        try await waitForGate(engine)
        controller.cancel()
        #expect(!FileManager.default.fileExists(atPath: rec.audio!.file.path))
        await engine.resume(); await task?.value
        #expect(controller.state == .cancelled)
        #expect(controller.text.isEmpty)
    }
    @Test(arguments: ["", "   ", "Hallo"])
    func emptyOutputAndEngineFailure(_ output: String) async throws {
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        let rec = RecorderDouble(); let engine = EngineDouble()
        await engine.configure(failure: output == "Hallo" ? .transcriptionFailed : nil, output: output)
        let controller = DictationController(recorder: rec, engine: engine)
        await controller.start(model: model)?.value
        await controller.stop()?.value
        #expect(controller.state == .failed)
        #expect(controller.errorMessage != nil)
        #expect(!FileManager.default.fileExists(atPath: rec.audio!.file.path))
    }
    @Test func cancelDuringRecordingDoesNotTranscribe() async throws {
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        let rec = RecorderDouble(); let engine = EngineDouble()
        let controller = DictationController(recorder: rec, engine: engine)
        await controller.start(model: model)?.value
        controller.cancel()
        #expect(controller.state == .cancelled)
        #expect(rec.cancels == 1)
        #expect(controller.stop() == nil)
        #expect(await engine.transcribeCalls == 0)
    }
    @Test func recorderFailureIsHandledAndTimedCompletionTranscribes() async throws {
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        let rec = RecorderDouble(); let engine = EngineDouble()
        let controller = DictationController(recorder: rec, engine: engine)
        await controller.start(model: model)?.value
        rec.onCompletion?(false)
        #expect(controller.state == .failed)
        #expect(controller.errorMessage == SpeechFailure.recordingFailed.errorDescription)
        await controller.start(model: model)?.value
        rec.onCompletion?(true)
        for _ in 0..<10_000 { if !controller.busy { break }; await Task.yield() }
        #expect(controller.state == .completed)
    }
    @Test func rejectsRemoteAndMalformedAssets() throws {
        #expect(throws: SpeechFailure.invalidAssets) { try LocalModelAssets(folder: URL(string: "https://example.invalid/model")!) }
        let model = try fixture(); defer { try? FileManager.default.removeItem(at: model) }
        try Data("broken".utf8).write(to: model.appendingPathComponent("tokenizer.json"))
        #expect(throws: SpeechFailure.invalidAssets) { try LocalModelAssets(folder: model) }
    }
}
