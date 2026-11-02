import AppKit
import SwiftUI
import Observation

@MainActor @Observable final class DesignPreview {
    static let shared = DesignPreview()
    var state = ProcessInfo.processInfo.environment["APP_SNAPSHOT_STATE"] ?? "empty"
    var mode = ProcessInfo.processInfo.environment["APP_APPEARANCE"] ?? "dark"
}

@MainActor enum Snapshot {
    static func runIfRequested(openSettings: OpenSettingsAction, renderDictation: () -> NSImage?) async {
        guard let folder = ProcessInfo.processInfo.environment["APP_SNAPSHOT"] else { return }
        if ProcessInfo.processInfo.environment["APP_SNAPSHOT_MATRIX"] == "1" {
            await runMatrix(folder: folder, openSettings: openSettings)
            return
        }
        let mode = ProcessInfo.processInfo.environment["APP_APPEARANCE"] ?? "dark"
        let state = ProcessInfo.processInfo.environment["APP_SNAPSHOT_STATE"] ?? "empty"
        do {
            guard ProcessInfo.processInfo.environment["APP_SNAPSHOT_RENDER"] == "1" || CGPreflightScreenCaptureAccess() else { throw CocoaError(.fileReadNoPermission) }
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try await Task.sleep(for: .seconds(1))
            guard let main = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" && $0.isVisible }) else {
                throw CocoaError(.fileNoSuchFile)
            }
            main.setContentSize(NSSize(width: 1040, height: 760))
            main.center()
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate(); main.makeKeyAndOrderFront(nil)
            main.contentView?.layoutSubtreeIfNeeded()
            main.contentView?.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(200))
            // Persist real window frames before the offscreen renderer owns probe IDs.
            GridProbes.shared.write(to: "\(folder)/dictation-\(state)-\(mode)-layout.json", window: main.contentView?.bounds.size ?? .zero)
            try await foreground(main)
            try capture(main, path: "\(folder)/dictation-\(state)-\(mode).png", rendered: ProcessInfo.processInfo.environment["APP_SNAPSHOT_RENDER"] == "1" ? renderDictation() : nil)
            openSettings()
            try await Task.sleep(for: .seconds(1))
            guard let settings = NSApp.windows.first(where: { $0.isVisible && $0 !== main && !$0.isSheet && $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }) else {
                throw CocoaError(.fileNoSuchFile)
            }
            for (tab, name) in [(0, "controls"), (1, "privacy"), (2, "appearance")] {
                VoiceRuntime.shared.settingsTab = tab
                try await Task.sleep(for: .milliseconds(200))
                try await foreground(settings)
                try capture(settings, path: "\(folder)/settings-\(name)-\(mode).png")
            }
            print("\(ProcessInfo.processInfo.environment["APP_SNAPSHOT_RENDER"] == "1" ? "CONTENT RENDER" : "SNAPSHOT") PASS \(mode)")
            NSApp.terminate(nil)
        } catch {
            FileHandle.standardError.write(Data("SNAPSHOT FAIL: \(error). GUI-Zugriff und bereits erteilte Bildschirmaufnahmeberechtigung prüfen.\n".utf8))
            exit(1)
        }
    }
    private static var matrixRunning = false
    private static func runMatrix(folder: String, openSettings: OpenSettingsAction) async {
        guard !matrixRunning else { return }
        matrixRunning = true
        do {
            guard CGPreflightScreenCaptureAccess() else { throw CocoaError(.fileReadNoPermission) }
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try await Task.sleep(for: .seconds(1))
            guard let main = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) else { throw CocoaError(.fileNoSuchFile) }
            main.setContentSize(NSSize(width: 1040, height: 760)); main.center()
            for mode in ["dark", "light"] {
                DesignPreview.shared.mode = mode
                for state in ["empty", "recording", "transcribing", "completed", "inserted", "unverified", "error", "long", "gallery"] {
                    DesignPreview.shared.state = state
                    try await Task.sleep(for: .milliseconds(200))
                    try await foreground(main)
                    main.contentView?.layoutSubtreeIfNeeded(); main.contentView?.displayIfNeeded()
                    GridProbes.shared.write(to: "\(folder)/dictation-\(state)-\(mode)-layout.json", window: main.contentView?.bounds.size ?? .zero)
                    try capture(main, path: "\(folder)/dictation-\(state)-\(mode).png")
                    if state == "empty" {
                        openSettings()
                        try await Task.sleep(for: .milliseconds(300))
                        guard let settings = NSApp.windows.first(where: { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }) else { throw CocoaError(.fileNoSuchFile) }
                        for (tab, name) in [(0, "controls"), (1, "privacy"), (2, "appearance")] {
                            VoiceRuntime.shared.settingsTab = tab
                            try await Task.sleep(for: .milliseconds(200))
                            try await foreground(settings)
                            try capture(settings, path: "\(folder)/settings-\(name)-\(mode).png")
                        }
                        settings.orderOut(nil)
                    }
                }
            }
            FileHandle.standardError.write(Data("MATRIX SNAPSHOT PASS\n".utf8))
            NSApp.terminate(nil)
        } catch {
            FileHandle.standardError.write(Data("MATRIX SNAPSHOT FAIL: \(error)\n".utf8)); exit(1)
        }
    }
    private static func foreground(_ window: NSWindow) async throws {
        for _ in 0..<200 {
            NSApp.unhide(nil)
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(100))
            if NSApp.isActive && window.isKeyWindow { return }
        }
        throw CocoaError(.userCancelled)
    }
    private static func capture(_ window: NSWindow, path: String, rendered: NSImage? = nil) throws {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(); window.makeKeyAndOrderFront(nil)
        FileHandle.standardError.write(Data("WINDOW active=\(NSApp.isActive) key=\(window.isKeyWindow)\n".utf8))
        if ProcessInfo.processInfo.environment["APP_SNAPSHOT_RENDER"] == "1" {
            // Explicit content-only render: no screen capture or privacy permission.
            // Does not prove system window chrome, compositing or Liquid Glass appearance.
            if let rendered, let tiff = rendered.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                try png.write(to: URL(fileURLWithPath: path))
                return
            }
            guard let view = window.contentView,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileReadUnknown) }
            view.displayIfNeeded()
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
            try png.write(to: URL(fileURLWithPath: path))
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileReadNoPermission)
        }
    }
}
