import AppKit
import Foundation

// Only the explicitly supplied project bundle; never activate /Applications.
let bundle = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let deadline = Date().addingTimeInterval(15)
while Date() < deadline {
    for app in NSWorkspace.shared.runningApplications where app.bundleURL?.standardizedFileURL == bundle {
        // Compatibility option is confined to this diagnostic helper, never the app.
        _ = app.activate(options: [.activateAllWindows])
    }
    Thread.sleep(forTimeInterval: 0.15)
}
