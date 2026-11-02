import Foundation
import Testing
import os
import CraftVoiceCore
@testable import CraftVoiceSpeech
import WhisperKit
import AVFoundation

// URLProtocol inherits unchecked Sendable from Foundation; all test-owned mutable
// state is guarded by OSAllocatedUnfairLock. No request is allowed to leave the process.
private final class NetworkTrap: URLProtocol, @unchecked Sendable {
    static let attempts = OSAllocatedUnfairLock(initialState: 0)
    override class func canInit(with request: URLRequest) -> Bool {
        attempts.withLock { $0 += 1 }
        return true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}

@Suite(.serialized) struct OfflineSpeechTests {
    @Test func configDisablesDownloadsAndFixesGerman() throws {
        let folder = URL(fileURLWithPath: "/tmp/CraftVoice-local-test")
        let config = try OfflineWhisperConfiguration.make(folder: folder)
        #expect(!config.download)
        #expect(config.load == false)
        #expect(config.prewarm == false)
        #expect(!config.useBackgroundDownloadSession)
        #expect(config.modelFolder == folder.path)
        #expect(config.tokenizerFolder == folder)
        #expect(config.computeOptions?.audioEncoderCompute == .cpuAndGPU)
        #expect(config.computeOptions?.textDecoderCompute == .cpuAndGPU)
        let options = OfflineWhisperConfiguration.germanOptions()
        #expect(options.language == "de")
        #expect(options.task == .transcribe)
        #expect(options.detectLanguage == false)
        #expect(options.verbose == false)
        #expect(options.windowClipTime == 1)
        #expect(throws: SpeechFailure.invalidAssets) { try OfflineWhisperConfiguration.make(folder: URL(string: "https://example.invalid")!) }
    }
    @Test func audioLoaderPreservesFinalSamplesBeyondThirtySeconds() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CraftVoice-tail-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("tail.wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let count: AVAudioFrameCount = 486_400 // 30.4 seconds: previously skipped final window.
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count))
        buffer.frameLength = count
        let channel = try #require(buffer.floatChannelData?[0])
        for index in 0..<Int(count) { channel[index] = index >= 480_000 ? 0.5 : 0 }
        do {
            let file = try AVAudioFile(forWriting: path, settings: format.settings)
            try file.write(from: buffer)
        }
        let samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: path.path)
        #expect(samples.count == Int(count))
        #expect(samples.last == 0.5)
        #expect(samples[480_000] == 0.5)
        #expect(OfflineWhisperConfiguration.germanOptions().windowClipTime == 1)
    }
    @Test func tailPolicyPreservesEvenExtremelyQuietSpeechAndDropsOnlyDigitalZeroSuffix() {
        #expect(AudioTailPolicy.retainedSampleCount([]) == 0)
        #expect(AudioTailPolicy.retainedSampleCount([0, 0, 0]) == 0)
        #expect(AudioTailPolicy.retainedSampleCount([0, 0.5, 0, 0]) == 2)
        #expect(AudioTailPolicy.retainedSampleCount([0, 0, Float.leastNonzeroMagnitude]) == 3)
        #expect(AudioTailPolicy.retainedSampleCount([0, -0.000001, 0]) == 2)
    }
    @Test(arguments: [480_001, 486_475, 496_000, 960_001, 966_475, 976_000, 1_440_001, 1_456_000])
    func balancedTailClipsCoverEverySampleExactlyOnce(_ count: Int) {
        let points = AudioTailPolicy.balancedClipTimestamps(sampleCount: count)
        #expect(!points.isEmpty)
        var positions = points.map { Int(round($0 * 16_000)) }
        positions.append(count)
        var lastEnd = 0
        var covered = 0
        for i in stride(from: 0, to: positions.count, by: 2) {
            let start = positions[i], end = positions[i + 1]
            #expect(start == lastEnd)
            #expect(end - start >= 240_000)
            covered += end - start; lastEnd = end
        }
        #expect(covered == count); #expect(lastEnd == count)
    }
    @Test(arguments: [16_000, 480_000, 496_001, 864_000, 960_000, 1_920_000])
    func normalAudioWindowsRemainUnchanged(_ count: Int) {
        #expect(AudioTailPolicy.balancedClipTimestamps(sampleCount: count).isEmpty)
    }
    @Test func invalidTokenizerNeverFallsBackToNetwork() async throws {
        NetworkTrap.attempts.withLock { $0 = 0 }
        #expect(URLProtocol.registerClass(NetworkTrap.self))
        defer { URLProtocol.unregisterClass(NetworkTrap.self) }
        // Positive control: prove the trap sees requests from URLSession.shared.
        do { _ = try await URLSession.shared.data(from: URL(string: "https://craftvoice.invalid/probe")!) }
        catch { /* NetworkTrap supplies the failure without a real connection. */ }
        #expect(NetworkTrap.attempts.withLock { $0 } > 0)
        NetworkTrap.attempts.withLock { $0 = 0 }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CraftVoice-offline-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let kit = try await OfflineWhisperKit(OfflineWhisperConfiguration.make(folder: folder))
        // Constructing with local paths and load=false must not contact the Hub.
        for content in [nil, "broken", "{}"] as [String?] {
            if let content {
                try Data(content.utf8).write(to: folder.appendingPathComponent("tokenizer.json"))
                try Data("{}".utf8).write(to: folder.appendingPathComponent("tokenizer_config.json"))
            }
            do { try await kit.loadTokenizerIfNeeded(); Issue.record("Malformed local tokenizer was accepted") }
            catch { /* Expected local failure; no network recovery. */ }
        }
        #expect(NetworkTrap.attempts.withLock { $0 } == 0)
    }
    @Test func localTokenizerBridgeUsesVocabularyWithoutSpecialTokenPrefix() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CraftVoice-tokenizer-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let vocab: [String: Int] = ["Ġ": 220, "H": 39, "a": 64, "l": 75, "o": 78,
            "<|endoftext|>": 50257, "<|startoftranscript|>": 50258, "<|en|>": 50259,
            "<|de|>": 50261, "<|translate|>": 50358, "<|transcribe|>": 50359,
            "<|startofprev|>": 50361, "<|nospeech|>": 50362,
            "<|notimestamps|>": 50363, "<|0.00|>": 50364]
        let data: [String: Any] = ["version": "1.0", "added_tokens": [],
            "model": ["type": "BPE", "vocab": vocab, "merges": []],
            "pre_tokenizer": ["type": "ByteLevel", "add_prefix_space": false, "use_regex": true],
            "decoder": ["type": "ByteLevel", "add_prefix_space": false, "trim_offsets": true, "use_regex": true]]
        try JSONSerialization.data(withJSONObject: data).write(to: folder.appendingPathComponent("tokenizer.json"))
        try JSONSerialization.data(withJSONObject: ["tokenizer_class": "WhisperTokenizer"]).write(to: folder.appendingPathComponent("tokenizer_config.json"))
        let wrapper = try await AutoTokenizerWrapper.from(modelFolder: folder)
        let tokenizer = try LocalGermanTokenizer(wrapper: wrapper)
        #expect(tokenizer.specialTokens.whitespaceToken == 220)
        #expect(tokenizer.specialTokens.timeTokenBegin == 50364)
        #expect(tokenizer.allLanguageTokens.contains(50261))
        #expect(tokenizer.decode(tokens: tokenizer.encode(text: "Hallo")) == "Hallo")
        let words = tokenizer.splitToWordTokens(tokenIds: [39, 64, 75, 75, 78, 220, 39, 64, 75, 75, 78])
        #expect(words.words == ["Hallo", " Hallo"])
        #expect(words.wordTokens.flatMap { $0 }.count == 11)
    }
    @Test func engineRejectsMissingModelsWithoutNetwork() async throws {
        NetworkTrap.attempts.withLock { $0 = 0 }
        #expect(URLProtocol.registerClass(NetworkTrap.self))
        defer { URLProtocol.unregisterClass(NetworkTrap.self) }
        let engine = LocalWhisperEngine()
        do {
            try await engine.prepare(model: URL(fileURLWithPath: "/tmp/CraftVoice-no-model-\(UUID())"))
            Issue.record("Missing assets were accepted")
        } catch { #expect(error is SpeechFailure) }
        do { _ = try await engine.transcribe(file: URL(fileURLWithPath: "/tmp/no-audio.wav")); Issue.record("Unprepared engine accepted") }
        catch { #expect(error is SpeechFailure) }
        #expect(NetworkTrap.attempts.withLock { $0 } == 0)
    }
    @Test @MainActor func microphonePermissionDeniedWithoutTouchingHardware() async {
        let recorder = MicrophoneRecorder(permission: { false }, hasDevice: { Issue.record("Hardware checked after denied permission"); return true })
        do { try await recorder.start(); Issue.record("Denied microphone started") }
        catch { #expect(error as? SpeechFailure == .permissionDenied) }
        recorder.cancel()
        #expect(throws: SpeechFailure.emptyRecording) { try recorder.stop() }
    }
    @Test @MainActor func missingMicrophoneIsReported() async {
        let recorder = MicrophoneRecorder(permission: { true }, hasDevice: { false })
        do { try await recorder.start(); Issue.record("Missing microphone started") }
        catch { #expect(error as? SpeechFailure == .noMicrophone) }
    }
    @Test @MainActor func cancelledPermissionRequestNeverStartsMicrophone() async {
        let recorder = MicrophoneRecorder(permission: { true }, hasDevice: { Issue.record("Device queried after cancellation"); return false })
        let operation = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            do { try await recorder.start(); Issue.record("Cancelled recording started") }
            catch { #expect(error is CancellationError) }
        }
        await operation.value
    }
}
