import Foundation
import CoreML
import CraftVoiceCore
import WhisperKit

/// Never calls WhisperKit's tokenizer loader: that loader falls back to the Hub
/// even when model downloads are disabled. This override has only local I/O.
final class OfflineWhisperKit: WhisperKit {
    override func loadTokenizerIfNeeded() async throws {
        guard let folder = tokenizerFolder, folder.isFileURL else { throw SpeechFailure.invalidAssets }
        let wrapper = try await AutoTokenizerWrapper.from(modelFolder: folder)
        try Task.checkCancellation()
        guard wrapper.convertTokenToId("<|de|>") != nil,
              wrapper.convertTokenToId("<|transcribe|>") != nil,
              let logits = textDecoder.logitsSize,
              [51_865, 51_866].contains(logits) else { throw SpeechFailure.invalidAssets }
        textDecoder.isModelMultilingual = true
        let local = try LocalGermanTokenizer(wrapper: wrapper)
        guard local.specialTokens.timeTokenBegin + 1_501 == logits else { throw SpeechFailure.invalidAssets }
        tokenizer = local
    }
}

public enum LocalWhisperCompute: Sendable { case recommended, cpuAndGPU }

public enum OfflineWhisperConfiguration {
    public static func make(folder: URL, compute: LocalWhisperCompute = .cpuAndGPU) throws -> WhisperKitConfig {
        guard folder.isFileURL else { throw SpeechFailure.invalidAssets }
        return WhisperKitConfig(modelFolder: folder.path, tokenizerFolder: folder,
            computeOptions: compute == .cpuAndGPU ? ModelComputeOptions(melCompute: .cpuAndGPU, audioEncoderCompute: .cpuAndGPU, textDecoderCompute: .cpuAndGPU) : nil,
            verbose: false, prewarm: false, load: false, download: false,
            useBackgroundDownloadSession: false)
    }
    public static func germanOptions() -> DecodingOptions {
        DecodingOptions(verbose: false, task: .transcribe, language: "de",
            temperature: 0, temperatureFallbackCount: 0, usePrefillPrompt: true,
            detectLanguage: false, skipSpecialTokens: true, withoutTimestamps: true, wordTimestamps: false,
            windowClipTime: 1, concurrentWorkerCount: 1)
    }
}

/// Owns library objects behind an actor; no UI work or concurrent access
/// to one WhisperKit instance. The pinned Swift-6.2 manifest preserves isolation.
public actor LocalWhisperEngine: SpeechTranscribing {
    private var kit: OfflineWhisperKit?
    private var loadedFolder: URL?
    private var running = false
    public private(set) var lastModelLoadFailure: String?
    public func modelLoadSummary() -> String {
        guard let kit else { return "unloaded" }
        return "state=\(kit.modelState) encoderDimensions=\(kit.audioEncoder.embedSize ?? 0) vocabularySize=\(kit.textDecoder.logitsSize ?? 0) germanToken=\(kit.tokenizer?.convertTokenToId("<|de|>") ?? -1)"
    }
    private let compute: LocalWhisperCompute
    public init(compute: LocalWhisperCompute = .cpuAndGPU) { self.compute = compute }
    public func prepare(model: URL) async throws {
        guard !running else { throw SpeechFailure.engineBusy }
        running = true
        defer { running = false }
        try Task.checkCancellation()
        _ = try LocalModelAssets(folder: model)
        if loadedFolder == model.standardizedFileURL, kit != nil { return }
        kit = nil; loadedFolder = nil; lastModelLoadFailure = nil
        do {
            let candidate = try await OfflineWhisperKit(OfflineWhisperConfiguration.make(folder: model, compute: compute))
            try Task.checkCancellation()
            try await candidate.loadModels()
            try Task.checkCancellation()
            kit = candidate; loadedFolder = model.standardizedFileURL
        } catch is CancellationError { throw CancellationError() }
        catch { lastModelLoadFailure = String(describing: error); throw SpeechFailure.invalidAssets }
    }
    public func transcribe(file: URL) async throws -> String {
        try await transcribe(file: file, options: OfflineWhisperConfiguration.germanOptions())
    }
    /// Offline replay of the same saved test audio. No normal app configuration change.
    public func transcribeDiagnostic(file: URL, clipStart: Float? = nil, windowClipTime: Float? = nil, legacyWindows: Bool = false) async throws -> String {
        var options = OfflineWhisperConfiguration.germanOptions()
        if let clipStart { options.clipTimestamps = [clipStart] }
        if let windowClipTime { options.windowClipTime = windowClipTime }
        return try await transcribe(file: file, options: options, balanceTail: !legacyWindows)
    }
    private func transcribe(file: URL, options: DecodingOptions, balanceTail: Bool = true) async throws -> String {
        guard !running else { throw SpeechFailure.engineBusy }
        guard let kit else { throw SpeechFailure.invalidAssets }
        running = true
        defer { running = false }
        try Task.checkCancellation()
        do {
            let loaded = try AudioProcessor.loadAudioAsFloatArray(fromPath: file.path)
            try Task.checkCancellation()
            let retained = AudioTailPolicy.retainedSampleCount(loaded)
            let samples = retained == loaded.count ? loaded : Array(loaded.prefix(retained))
            guard !samples.isEmpty else { return "" }
            var effectiveOptions = options
            if balanceTail && options.clipTimestamps.isEmpty {
                effectiveOptions.clipTimestamps = AudioTailPolicy.balancedClipTimestamps(sampleCount: samples.count)
            }
            let results = try await kit.transcribe(audioArray: samples,
                decodeOptions: effectiveOptions, callback: { _ in !Task.isCancelled })
            try Task.checkCancellation()
            let text = results.map(\.text).joined(separator: " ")
            let segments: [[String: Any]] = results.flatMap(\.segments).map {
                ["seek": $0.seek, "start": $0.start, "end": $0.end, "text": $0.text,
                 "tokenCount": $0.tokens.count, "noSpeechProb": $0.noSpeechProb]
            }
            let folder = LocalDiagnosticCapture.folder(for: file)
            LocalDiagnosticCapture.text(text, name: "whisper-text.txt", folder: folder)
            LocalDiagnosticCapture.json(["windowClipTime": effectiveOptions.windowClipTime,
                "clipTimestamps": effectiveOptions.clipTimestamps,
                "inputSamples": loaded.count, "retainedSamples": retained,
                "trailingDigitalZeroSamples": loaded.count - retained,
                "results": results.count, "segments": segments], name: "whisper-segments.json", folder: folder)
            return text
        } catch is CancellationError { throw CancellationError() }
        catch { throw SpeechFailure.transcriptionFailed }
    }
}
