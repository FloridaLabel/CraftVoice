import AppKit
import SwiftUI
import CraftVoiceCore

struct VoiceMenu: View {
    let runtime: VoiceRuntime
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    private var actionTitle: String {
        switch runtime.controller.state {
        case .preparing: "Vorbereitung abbrechen"
        case .recording: "Aufnahme beenden"
        case .transcribing: "Erkennung läuft …"
        default: "Aufnahme starten"
        }
    }
    var body: some View {
        Label("CraftVoice · Lokal diktieren", systemImage: KitIcon.offline)
        Divider()
        Text(runtime.inserting ? "Text wird eingefügt …" : runtime.controller.status)
        Button(actionTitle) { runtime.toggleGlobal() }
            .disabled(runtime.inserting || runtime.controller.state == .transcribing)
        Button("Abbrechen") { runtime.cancel() }.disabled(!runtime.busy)
        Text("Umschalten: \(runtime.shortcuts.toggle.title)")
        Divider()
        Text(runtime.inputStatus).lineLimit(2)
        if runtime.clipboardPending {
            Button("Vorherige Zwischenablage wiederherstellen") { runtime.restoreClipboard() }
        }
        Button("Diktatfenster öffnen") { NSApp.activate(); openWindow(id: "main") }
        Button("Einstellungen …") { NSApp.activate(); openSettings() }
        Divider()
        Button("CraftVoice beenden") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

struct Phase3Settings: View {
    @Bindable var runtime: VoiceRuntime
    @AppStorage("appearance") private var appearance = "dark"
    @State private var draft = ShortcutConfiguration()
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(spacing: Space.md) {
                Image(systemName: KitIcon.settings).font(KitType.title).foregroundStyle(Ink.identity)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Dein CraftVoice").font(KitType.title)
                    Text("Schnell erreichbar. Vollständig lokal.").font(KitType.detail).foregroundStyle(Ink.muted)
                }
                Spacer()
                StatusBadge(title: "Auf diesem Mac", symbol: KitIcon.offline)
            }.padding(.horizontal, Space.xl).padding(.top, Space.xl)
            TabView(selection: $runtime.settingsTab) {
            Form {
                Section("Globale Tastenkürzel") {
                    ShortcutEditor(title: "Aufnahme starten / beenden", value: $draft.toggle)
                    Button("Tastenkürzel übernehmen") { runtime.applyShortcuts(draft) }.disabled(runtime.busy)
                    if let error = runtime.shortcutError { Text(error).foregroundStyle(.red) }
                }
                Section("Texteingabe") {
                    Toggle("Erkannten Text automatisch einfügen", isOn: $runtime.autoInsert).disabled(runtime.busy)
                    Toggle("Zwischenablage als Ausweichweg verwenden", isOn: $runtime.clipboardFallback).disabled(runtime.busy)
                        .help("Bei unbestätigtem Einfügen lässt sich die vorherige Zwischenablage ausdrücklich über das Menü wiederherstellen.")
                    Text("Bei einem Zielwechsel bleibt der Text in CraftVoice. Ohne bestätigtes Einfügen erfolgt kein zweiter Versuch.")
                        .font(KitType.detail).foregroundStyle(.secondary)
                    if runtime.clipboardPending { Button("Vorherige Zwischenablage wiederherstellen") { runtime.restoreClipboard() } }
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden).tabItem { Label("Bedienung", systemImage: "keyboard") }.tag(0)
            Form {
                LabeledContent("Bedienungshilfen", value: runtime.accessibilityGranted ? "Erlaubt" : "Nicht erlaubt")
                Button("Bedienungshilfen erlauben …") { runtime.requestAccessibility() }.disabled(runtime.accessibilityGranted)
                Text("Nur für das Prüfen des ursprünglichen Textfelds und die automatische Texteingabe erforderlich.").foregroundStyle(.secondary)
                if runtime.clipboardFallback {
                    LabeledContent("Eingabeereignisse", value: runtime.postingGranted ? "Erlaubt" : "Nicht erlaubt")
                    Button("Eingabeereignisse erlauben …") { runtime.requestPosting() }.disabled(runtime.postingGranted)
                }
                Text("Das Mikrofon wird erst beim Aufnehmen verwendet. Globale Tastenkürzel benötigen keine Eingabeüberwachung.")
                    .foregroundStyle(.secondary)
            }.formStyle(.grouped).scrollContentBackground(.hidden).tabItem { Label("Datenschutz", systemImage: "hand.raised") }.tag(1)
            Form {
                Picker("Erscheinungsbild", selection: $appearance) {
                    Text("Dunkel").tag("dark"); Text("Hell").tag("light"); Text("Systemeinstellung").tag("system")
                }
                Text("Spracherkennung und Modelle bleiben lokal auf diesem Mac.").foregroundStyle(.secondary)
            }.formStyle(.grouped).scrollContentBackground(.hidden).tabItem { Label("Darstellung", systemImage: "circle.lefthalf.filled") }.tag(2)
        }
            .padding(.horizontal, Space.sm).padding(.bottom, Space.sm)
        }
        .foregroundStyle(Ink.text).background(Ink.canvas).tint(Ink.accentText)
        .frame(width: 680, height: runtime.settingsTab == 0 ? 520 : runtime.settingsTab == 1 ? 360 : 280)
        .onAppear { draft = runtime.shortcuts; runtime.refreshPermissions() }
        .task {
            while !Task.isCancelled {
                runtime.refreshPermissions()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}

private struct ShortcutEditor: View {
    let title: String
    @Binding var value: GlobalShortcut
    private let keys: [ShortcutKey] = [.space, .f6, .f7, .f8, .f9, .f10, .f11, .f12]
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Picker(title, selection: $value.key) {
                ForEach(keys, id: \.self) { Text($0.title).tag($0) }
            }
            HStack(spacing: Space.md) {
                Toggle("⌃ Control", isOn: $value.control)
                Toggle("⌥ Option", isOn: $value.option)
                Toggle("⌘ Command", isOn: $value.command)
                Toggle("⇧ Shift", isOn: $value.shift)
            }.toggleStyle(.checkbox)
        }.padding(.vertical, Space.xs)
    }
}
