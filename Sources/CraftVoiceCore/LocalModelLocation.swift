import Foundation

public enum LocalModelLocation {
    public static func defaultFolder(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/CraftVoice/Models/large-v3-turbo", isDirectory: true)
    }
}
