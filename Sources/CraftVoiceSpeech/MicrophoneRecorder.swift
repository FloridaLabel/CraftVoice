import AVFoundation
import Foundation
import CraftVoiceCore

@MainActor public final class MicrophoneRecorder: NSObject, AudioRecording, AVAudioRecorderDelegate {
    public var onCompletion: (@MainActor @Sendable (Bool) -> Void)?
    private var recorder: AVAudioRecorder?
    private var directory: URL?
    private let permission: @MainActor () async -> Bool
    private let hasDevice: @MainActor () -> Bool
    public override init() {
        permission = Self.requestPermission
        hasDevice = { AVCaptureDevice.default(for: .audio) != nil }
        super.init()
    }
    init(permission: @escaping @MainActor () async -> Bool, hasDevice: @escaping @MainActor () -> Bool) {
        self.permission = permission; self.hasDevice = hasDevice
        super.init()
    }
    private static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    public func start() async throws {
        cancel()
        let granted = await permission()
        try Task.checkCancellation()
        guard granted else { throw SpeechFailure.permissionDenied }
        guard hasDevice() else { throw SpeechFailure.noMicrophone }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CraftVoice-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700])
            directory = folder
            let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false]
            let audio = try AVAudioRecorder(url: folder.appendingPathComponent("recording.wav"), settings: settings)
            audio.delegate = self
            guard audio.prepareToRecord(), audio.record(forDuration: 120) else { throw SpeechFailure.recordingFailed }
            recorder = audio
        } catch {
            cancel()
            throw SpeechFailure.recordingFailed
        }
    }
    public func stop() throws -> RecordedAudio {
        guard let audio = recorder, let folder = directory else { throw SpeechFailure.emptyRecording }
        recorder = nil; directory = nil
        let recorderSeconds = audio.currentTime
        audio.delegate = nil; audio.stop()
        let result = RecordedAudio(file: audio.url, directory: folder)
        guard let bytes = try? result.file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              bytes > 44 else { result.discard(); throw SpeechFailure.emptyRecording }
        if let file = try? AVAudioFile(forReading: audio.url) {
            LocalDiagnosticCapture.begin(audio: audio.url, metadata: ["recorderSeconds": recorderSeconds,
                "sampleRate": file.processingFormat.sampleRate, "frames": file.length,
                "fileSeconds": Double(file.length) / file.processingFormat.sampleRate])
        }
        return result
    }
    public func cancel() {
        recorder?.delegate = nil
        recorder?.stop(); recorder = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let identity = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == identity else { return }
            self.onCompletion?(flag)
        }
    }
    nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        let identity = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == identity else { return }
            self.onCompletion?(false)
        }
    }
}
