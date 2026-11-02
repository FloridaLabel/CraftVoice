import Foundation

public enum SpeechFailure: Error, LocalizedError, Equatable, Sendable {
    case missingAssets(String), invalidAssets, permissionDenied, noMicrophone, recordingFailed
    case emptyRecording, noSpeech, engineBusy, transcriptionFailed
    public var errorDescription: String? {
        switch self {
        case .missingAssets(let name): "Lokale Modelldatei fehlt: \(name). Wähle einen vollständigen lokalen Modellordner."
        case .invalidAssets: "Die lokalen Modelldateien sind nicht lesbar oder nicht kompatibel. Prüfe Modell und Tokenizer."
        case .permissionDenied: "Mikrofonzugriff fehlt. Erlaube CraftVoice den Zugriff in den Systemeinstellungen unter Datenschutz & Sicherheit → Mikrofon."
        case .noMicrophone: "Kein verwendbares Mikrofon gefunden. Prüfe das Eingabegerät und versuche es erneut."
        case .recordingFailed: "Die Aufnahme ist fehlgeschlagen. Prüfe das Mikrofon und starte erneut."
        case .emptyRecording: "Die Aufnahme enthält kein verwendbares Audio. Starte eine neue Aufnahme."
        case .noSpeech: "Keine Sprache erkannt. Starte eine neue Aufnahme und sprich deutlich."
        case .engineBusy: "Die vorherige Verarbeitung wird noch beendet. Versuche es gleich erneut."
        case .transcriptionFailed: "Die lokale Erkennung ist fehlgeschlagen. Prüfe die Modelldateien und versuche es erneut."
        }
    }
}

/// A structural preflight, not proof that model weights or tokenizer semantics are valid.
public struct LocalModelAssets: Sendable {
    public let folder: URL
    public static let modelNames = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
    public init(folder: URL) throws {
        guard folder.isFileURL else { throw SpeechFailure.invalidAssets }
        self.folder = folder.standardizedFileURL
        for name in Self.modelNames {
            let candidates = ["mlmodelc", "mlpackage"].map { folder.appendingPathComponent("\(name).\($0)") }
            guard candidates.contains(where: { url in
                var directory: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
                    && directory.boolValue && FileManager.default.isReadableFile(atPath: url.path)
            }) else { throw SpeechFailure.missingAssets(name) }
        }
        for name in ["tokenizer.json", "tokenizer_config.json"] {
            let url = folder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { throw SpeechFailure.missingAssets(name) }
            guard let data = try? Data(contentsOf: url), !data.isEmpty,
                  (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else {
                throw SpeechFailure.invalidAssets
            }
        }
    }
}

public struct RecordedAudio: Sendable {
    public let file: URL
    public let directory: URL
    public init(file: URL, directory: URL) { self.file = file; self.directory = directory }
    public func discard() { try? FileManager.default.removeItem(at: directory) }
}

@MainActor public protocol AudioRecording: AnyObject {
    var onCompletion: (@MainActor @Sendable (Bool) -> Void)? { get set }
    func start() async throws
    func stop() throws -> RecordedAudio
    func cancel()
}

public protocol SpeechTranscribing: Sendable {
    func prepare(model: URL) async throws
    func transcribe(file: URL) async throws -> String
}
