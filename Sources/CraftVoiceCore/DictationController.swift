import Foundation
import Observation

@Observable @MainActor public final class DictationController {
    public enum State: Equatable, Sendable {
        case idle, preparing, recording, transcribing, completed, cancelled, failed
    }
    public private(set) var state: State = .idle
    public private(set) var text = ""
    public private(set) var errorMessage: String?
    @ObservationIgnored public var onResult: (@MainActor (String) -> Void)?
    @ObservationIgnored public var onEnd: (@MainActor () -> Void)?
    @ObservationIgnored private let recorder: any AudioRecording
    @ObservationIgnored private let engine: any SpeechTranscribing
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var captured: RecordedAudio?

    public init(recorder: any AudioRecording, engine: any SpeechTranscribing) {
        self.recorder = recorder
        self.engine = engine
        recorder.onCompletion = { [weak self] success in
            guard let self, self.state == .recording else { return }
            if success { self.stop() }
            else { self.failRecording() }
        }
    }
    public var busy: Bool { [.preparing, .recording, .transcribing].contains(state) }
    public var status: String {
        switch state {
        case .idle: "Bereit für ein Diktat"
        case .preparing: "Lokales Modell wird geladen …"
        case .recording: "Aufnahme läuft – maximal 2 Minuten"
        case .transcribing: "Deutsch wird lokal erkannt …"
        case .completed: "Diktat erkannt"
        case .cancelled: "Diktat abgebrochen"
        case .failed: "Diktat nicht abgeschlossen"
        }
    }
    @discardableResult public func start(model: URL) -> Task<Void, Never>? {
        guard !busy else { return nil }
        let id = UUID(); generation = id
        errorMessage = nil
        state = .preparing
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try LocalModelAssets(folder: model)
                try Task.checkCancellation()
                try await self.engine.prepare(model: model)
                try Task.checkCancellation()
                guard self.generation == id else { return }
                try await self.recorder.start()
                // Permission requests cannot be dismissed programmatically. The recorder
                // must check cancellation before opening the microphone on return.
                try Task.checkCancellation()
                guard self.generation == id else { return }
                self.state = .recording
            } catch {
                guard self.generation == id else { return }
                self.recorder.cancel()
                self.report(error)
            }
        }
        return operation
    }
    @discardableResult public func stop() -> Task<Void, Never>? {
        guard state == .recording else { return nil }
        let id = generation
        state = .transcribing
        do { captured = try recorder.stop() }
        catch { recorder.cancel(); report(error); return nil }
        guard let audio = captured else { report(SpeechFailure.emptyRecording); return nil }
        operation = Task { [weak self] in
            defer { audio.discard() }
            guard let self else { return }
            do {
                let result = try await self.engine.transcribe(file: audio.file)
                try Task.checkCancellation()
                guard self.generation == id else { return }
                guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpeechFailure.noSpeech }
                self.text = result.trimmingCharacters(in: .whitespacesAndNewlines)
                self.state = .completed
                self.captured = nil
                self.onResult?(self.text)
                self.onEnd?()
            } catch {
                guard self.generation == id else { return }
                self.captured = nil
                self.report(error)
            }
        }
        return operation
    }
    public func cancel() {
        generation = UUID()
        operation?.cancel(); operation = nil
        recorder.cancel()
        captured?.discard(); captured = nil
        errorMessage = nil
        state = .cancelled
        onEnd?()
    }
    private func failRecording() {
        operation?.cancel()
        generation = UUID()
        recorder.cancel()
        report(SpeechFailure.recordingFailed)
    }
    private func report(_ error: Error) {
        defer { onEnd?() }
        if error is CancellationError { state = .cancelled; errorMessage = nil }
        else {
            state = .failed
            // Do not expose library error descriptions that may contain recognized text or paths.
            errorMessage = (error as? SpeechFailure)?.errorDescription ?? SpeechFailure.transcriptionFailed.errorDescription
        }
    }
}
