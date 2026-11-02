import Foundation
import CraftVoiceCore
import CraftVoiceSpeech

/// Loads the same offline engine as the app, without audio or GUI permissions.
@main struct ModelProbe {
    static func emit(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        func argument(_ flag: String) -> String? {
            guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
            return args[index + 1]
        }
        let folder = argument("--model").map { URL(fileURLWithPath: $0) }
            ?? (args.first.flatMap { $0.hasPrefix("--") ? nil : URL(fileURLWithPath: $0) })
            ?? LocalModelLocation.defaultFolder()
        emit("MODEL \(folder.path)")
        let engine = LocalWhisperEngine(compute: CommandLine.arguments.contains("--recommended") ? .recommended : .cpuAndGPU)
        let start = Date()
        do {
            try await engine.prepare(model: folder)
            emit("LOAD PASS \(await engine.modelLoadSummary()) seconds=\(Date().timeIntervalSince(start))")
            if let audio = argument("--audio") {
                let text = try await engine.transcribeDiagnostic(file: URL(fileURLWithPath: audio),
                    clipStart: argument("--clip-start").flatMap(Float.init),
                    windowClipTime: argument("--window-clip-time").flatMap(Float.init), legacyWindows: args.contains("--legacy-windows"))
                guard let output = argument("--output") else { emit("REPLAY FAIL: --output required; text not printed"); exit(1) }
                try Data(text.utf8).write(to: URL(fileURLWithPath: output), options: .atomic)
                emit("REPLAY PASS utf16=\(text.utf16.count)")
            }
        } catch {
            emit("LOAD FAIL \(error.localizedDescription)")
            if let detail = await engine.lastModelLoadFailure { emit("DETAIL \(detail)") }
            exit(1)
        }
    }
}
