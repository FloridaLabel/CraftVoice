import Foundation

/// Opt-in local test artifacts only. Never enabled by preferences or normal launch.
/// Dictation content is never written to Unified Logging or sent over a network.
public enum LocalDiagnosticCapture {
    private static var root: URL? {
        guard let path = ProcessInfo.processInfo.environment["CRAFTVOICE_DIAGNOSTICS_DIR"], path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
    public static var latestFolder: URL? {
        guard let root, let name = try? String(contentsOf: root.appendingPathComponent("latest-session.txt"), encoding: .utf8),
              name.hasPrefix("CraftVoice-"), !name.contains("/"), !name.contains("..") else { return nil }
        return root.appendingPathComponent(name, isDirectory: true)
    }
    public static func folder(for file: URL) -> URL? {
        root?.appendingPathComponent(file.deletingLastPathComponent().lastPathComponent, isDirectory: true)
    }
    public static func begin(audio: URL, metadata: [String: Any]) {
        guard let root, let folder = folder(for: audio) else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let copy = folder.appendingPathComponent("recording.wav")
            try FileManager.default.copyItem(at: audio, to: copy)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: copy.path)
            text(folder.lastPathComponent, name: "latest-session.txt", folder: root)
            json(metadata, name: "recording.json", folder: folder)
        } catch { /* Diagnostic capture never changes recording or delivery behavior. */ }
    }
    public static func text(_ text: String, name: String, folder: URL? = nil) {
        guard let folder = folder ?? latestFolder else { return }
        do {
            let path = folder.appendingPathComponent(name)
            try Data(text.utf8).write(to: path, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        } catch { }
    }
    public static func json(_ value: [String: Any], name: String, folder: URL? = nil) {
        guard let folder = folder ?? latestFolder, let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) else { return }
        text(String(decoding: data, as: UTF8.self), name: name, folder: folder)
    }
}
