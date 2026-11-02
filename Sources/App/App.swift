import AppKit
import SwiftUI
import ExampleKit
import CraftVoiceCore
import CraftVoiceSpeech

@main struct CraftVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var runtime = VoiceRuntime.shared
    @State private var preview = DesignPreview.shared
    private var controller: DictationController { runtime.controller }
    @AppStorage("appearance") private var appearance = AppearanceChoice.defaultChoice.rawValue
    @AppStorage("localModelPath") private var modelPath = ""
    private var scheme: ColorScheme? {
        switch ProcessInfo.processInfo.environment["APP_SNAPSHOT_MATRIX"] == "1" ? preview.mode : (ProcessInfo.processInfo.environment["APP_APPEARANCE"] ?? appearance) {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
    private var modelURL: URL {
        if !modelPath.isEmpty { return URL(fileURLWithPath: modelPath, isDirectory: true) }
        return LocalModelLocation.defaultFolder()
    }
    var body: some Scene {
        let busy = runtime.busy
        let recording = controller.state == .recording
        Window("Diktat", id: "main") {
            DictationView(controller: controller, modelURL: modelURL, chooseModel: chooseModel)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .preferredColorScheme(scheme)
                .frame(minWidth: 900, minHeight: 760)
                .noInitialFocus()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in runtime.shutdown() }
        }
        .defaultLaunchBehavior(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil && !CommandLine.arguments.contains("--show-window") ? .suppressed : .presented)
        .defaultSize(width: 1040, height: 800)
        .windowToolbarStyle(.unified)
        .commands {
            CommandMenu("Diktat") {
                Button("Aufnahme starten") { runtime.startLocal() }
                    .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(busy)
                Button("Aufnahme beenden") { runtime.stop() }
                    .keyboardShortcut("s", modifiers: [.command, .shift]).disabled(!recording)
                Button("Abbrechen") { runtime.cancel() }.disabled(!busy)
            }
        }
        MenuBarExtra {
            VoiceMenu(runtime: runtime)
        } label: {
            Label("CraftVoice", systemImage: controller.state == .recording ? "mic.fill" : "waveform")
                .help(controller.status)
        }.menuBarExtraStyle(.menu)
        Settings {
            Phase3Settings(runtime: runtime)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .preferredColorScheme(scheme).noInitialFocus()
        }
        .windowResizability(.contentSize)
    }
    @MainActor private func chooseModel() {
        guard !runtime.busy else { return }
        let panel = NSOpenPanel()
        panel.title = "Lokalen Modellordner wählen"
        panel.prompt = "Auswählen"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url { modelPath = url.path }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let diagnostic = ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil || CommandLine.arguments.contains("--show-window")
        NSApp.setActivationPolicy(diagnostic ? .regular : .accessory)
        VoiceRuntime.shared.boot()
        if diagnostic { NSApp.activate() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { VoiceRuntime.shared.shutdown() }
}
