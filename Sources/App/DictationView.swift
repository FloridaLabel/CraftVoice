import AppKit
import SwiftUI
import CraftVoiceCore
import CraftVoiceSpeech

struct DictationView: View {
    @Environment(\.openSettings) private var openSettings
    let controller: DictationController
    let modelURL: URL
    let chooseModel: () -> Void
    private var fixture: String? {
        guard ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil else { return nil }
        return DesignPreview.shared.state
    }
    private var state: DictationController.State {
        switch fixture {
        case "recording": .recording
        case "transcribing": .transcribing
        case "completed", "inserted", "unverified", "long": .completed
        case "error": .failed
        default: controller.state
        }
    }
    private var text: String {
        if fixture == "long" { return String(repeating: "Präzision beginnt mit klaren Worten. Bitte prüfe die Maße des Werkstücks: 12,5 Millimeter. Anschließend bereiten wir die nächste Fertigungsstufe vor.\n\n", count: 30) }
        return ["completed", "inserted", "unverified"].contains(fixture ?? "") ? "Bitte prüfe die Maße des Werkstücks: 12,5 Millimeter. Anschließend können wir die nächste Fertigungsstufe vorbereiten." : controller.text
    }
    private var error: String? { fixture == "error" ? SpeechFailure.permissionDenied.errorDescription : controller.errorMessage }
    private var busy: Bool { [.preparing, .recording, .transcribing].contains(state) || (fixture == nil && VoiceRuntime.shared.inserting) }
    private var title: String {
        switch state {
        case .recording: "Ich höre zu."
        case .preparing: "Einen Moment."
        case .transcribing: "Aus Sprache wird Text."
        case .completed: "Deine Worte. Klar erfasst."
        case .failed: "Noch nicht abgeschlossen."
        default: "Raum für deine Worte."
        }
    }
    private var status: String {
        switch state {
        case .recording: "Aufnahme läuft"
        case .preparing: "Modell wird vorbereitet"
        case .transcribing: "Spracherkennung läuft"
        case .completed: inputConfirmed ? "Text eingefügt" : inputWarning ? "Einfügen nicht bestätigt" : "Text erkannt"
        case .failed: "Fehler"
        default: "Bereit"
        }
    }
    private var symbol: String {
        switch state {
        case .recording: KitIcon.mic
        case .preparing, .transcribing: KitIcon.processing
        case .completed: inputWarning ? KitIcon.warning : KitIcon.success
        case .failed: KitIcon.error
        default: KitIcon.ready
        }
    }
    private var statusColor: Color {
        if state == .failed || state == .recording || inputWarning { return Ink.warning }
        return state == .completed ? Ink.success : Ink.accentText
    }
    private var inputMessage: String {
        if fixture == "completed" || fixture == "long" { return "Text erkannt und in CraftVoice bereitgestellt." }
        if fixture == "inserted" { return "Text eingefügt." }
        if fixture == "unverified" { return "Texteingabe gesendet, aber nicht verifizierbar. Prüfe die Zielanwendung; CraftVoice versucht es nicht erneut." }
        return VoiceRuntime.shared.inputStatus
    }
    // Presentation only: retain exact runtime messages, never infer delivery to drive logic.
    private var inputConfirmed: Bool { inputMessage == InsertionOutcome.inserted.message || inputMessage == InsertionOutcome.payloadPresent.message }
    private var inputWarning: Bool { inputMessage == InsertionOutcome.inputUnverified.message || inputMessage == InsertionOutcome.acceptedUnverified.message || inputMessage == InsertionOutcome.interrupted.message || inputMessage == InsertionOutcome.uncertain.message }
    private var header: some View {
        HStack(alignment: .center, spacing: Space.md) {
            Image(nsImage: NSImage(named: NSImage.Name("AppIcon")) ?? NSImage()).resizable().frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("CraftVoice").font(KitType.title)
                Text("Deine Stimme. Dein Mac.").font(KitType.detail).foregroundStyle(Ink.muted)
            }
            Spacer()
            StatusBadge(title: "Vollständig lokal", symbol: KitIcon.offline)
            Button { openSettings() } label: { Image(systemName: KitIcon.settings).font(KitType.section) }
                .buttonStyle(.borderless).help("Einstellungen öffnen (⌘,)").accessibilityLabel("Einstellungen öffnen")
        }
    }
    private var recordingPanel: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            StatusBadge(title: status, symbol: symbol, color: statusColor)
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Ink.identity.opacity(0.15), lineWidth: 1).frame(width: Metric.orbit + 32, height: Metric.orbit + 32)
                Circle().fill(RadialGradient(colors: [Ink.accent.opacity(0.15), Ink.identity.opacity(0.05)], center: .center, startRadius: 0, endRadius: 80))
                    .overlay(Circle().stroke(Ink.accent.opacity(0.35), lineWidth: 1)).frame(width: Metric.orbit, height: Metric.orbit)
                Image(systemName: [.preparing, .transcribing].contains(state) ? KitIcon.processing : KitIcon.mic).font(KitType.hero).foregroundStyle(statusColor)
            }.frame(maxWidth: .infinity).frame(height: 120).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title).font(KitType.title).fixedSize(horizontal: false, vertical: true)
                Text(state == .recording ? "Sprich in deinem Tempo. Beende die Aufnahme, wenn du fertig bist." : "Deutsch diktieren. Ohne Cloud, direkt auf deinem Mac.")
                    .font(KitType.body).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(spacing: Space.sm) {
                Button {
                    guard fixture == nil else { return }
                    if state == .recording { VoiceRuntime.shared.stop() } else { VoiceRuntime.shared.startLocal() }
                } label: { Label(state == .recording ? "Aufnahme beenden" : "Aufnahme starten", systemImage: state == .recording ? KitIcon.stop : KitIcon.mic) }
                    .buttonStyle(StudioActionStyle()).disabled(busy && state != .recording)
                    .help(state == .recording ? "Aufnahme beenden und lokal erkennen (⌘⇧S)" : "Aufnahme in CraftVoice starten (⌘⇧R)")
                Button("Abbrechen") { if fixture == nil { VoiceRuntime.shared.cancel() } }
                    .buttonStyle(StudioActionStyle(prominent: false)).disabled(!busy).keyboardShortcut(.cancelAction)
            }
            Text("Hier gestartet, bleibt dein Text in CraftVoice. Für direkte Texteingabe nutze das globale Kürzel im Zielprogramm.")
                .font(KitType.micro).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(width: Metric.rail).studioPanel()
    }
    private var resultText: some View {
        Text(text).font(KitType.body).lineSpacing(Space.sm).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading).padding(Space.xxl)
    }
    @ViewBuilder private var resultBody: some View {
        if text.isEmpty {
            VStack(spacing: Space.lg) {
                Image(systemName: KitIcon.text).font(KitType.hero).foregroundStyle(Ink.identity)
                Text("Gedanken werden Worte.").font(KitType.section)
                Text("Starte eine Aufnahme. Dein erkannter Text\nerscheint hier – nur auf diesem Mac.")
                    .font(KitType.body).foregroundStyle(Ink.muted).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if ProcessInfo.processInfo.environment["APP_SNAPSHOT_RENDER"] == "1" {
            resultText.frame(maxHeight: .infinity, alignment: .topLeading).clipped()
        } else {
            ScrollView { resultText }.scrollBounceBehavior(.basedOnSize)
        }
    }
    private var transcript: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Text("Erkannter Text").font(KitType.section)
                Spacer()
                Text("\(text.count) Zeichen").font(KitType.micro).monospacedDigit().foregroundStyle(Ink.muted)
                Button("Text kopieren", systemImage: KitIcon.copy) {
                    guard fixture == nil, !text.isEmpty else { return }
                    NSPasteboard.general.prepareForNewContents(with: .currentHostOnly)
                    NSPasteboard.general.setString(text, forType: .string)
                }.buttonStyle(.borderless).font(KitType.detail).disabled(text.isEmpty || VoiceRuntime.shared.clipboardPending)
                    .help("Erkannten Text auf diesem Mac in die Zwischenablage kopieren")
            }
            resultBody.background(Ink.inset, in: RoundedRectangle(cornerRadius: Metric.controlRadius))
                .accessibilityLabel("Erkannter Text")
            HStack(alignment: .top, spacing: Space.sm) {
                Image(systemName: inputConfirmed ? KitIcon.success : inputWarning ? KitIcon.warning : KitIcon.ready)
                    .foregroundStyle(inputConfirmed ? Ink.success : inputWarning ? Ink.warning : Ink.muted)
                Text(inputMessage).font(KitType.detail).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            }
            if let error {
                Label(error, systemImage: KitIcon.error).font(KitType.detail).foregroundStyle(Ink.warning).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).studioPanel()
    }
    private var footer: some View {
        HStack(alignment: .top, spacing: Space.xxl) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Label("Lokales Sprachmodell", systemImage: KitIcon.model).font(KitType.micro).foregroundStyle(Ink.identity)
                Text(modelURL.lastPathComponent).font(KitType.section).lineLimit(1).help(modelURL.path)
                Button("Modellordner ändern …") { if fixture == nil { chooseModel() } }.buttonStyle(.link).font(KitType.detail).disabled(busy)
                    .help("Eingerichteter Modellordner: \(modelURL.path). Anderen lokalen Ordner auswählen; kein Download.")
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: Space.sm) {
                ShortcutTile(title: "Start / Stopp", shortcut: VoiceRuntime.shared.shortcuts.toggle.title)
            }.frame(maxWidth: .infinity)
        }.padding(Space.lg).background(Ink.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: Metric.radius))
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            header.gridProbe("heading", area: "dictation")
            HStack(alignment: .top, spacing: Space.lg) {
                recordingPanel.frame(maxHeight: .infinity)
                transcript
            }.frame(maxWidth: .infinity, maxHeight: .infinity).gridProbe("workspace", area: "dictation")
            footer.gridProbe("model", area: "dictation")
            Label("Kein Upload. Keine automatischen Downloads. Audio wird nach Erkennung oder Abbruch gelöscht.", systemImage: KitIcon.offline)
                .font(KitType.micro).foregroundStyle(Ink.muted).gridProbe("privacy", area: "dictation")
        }.padding(Space.margin).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Ink.text).background(Ink.canvas).tint(Ink.accentText).gridArea("dictation")
    }
    @ViewBuilder private var display: some View {
        if fixture == "gallery" || ProcessInfo.processInfo.environment["APP_KIT_GALLERY"] == "1" { KitGallery() } else { content }
    }
    var body: some View {
        display.task {
            await Snapshot.runIfRequested(openSettings: openSettings, renderDictation: {
                let mode = ProcessInfo.processInfo.environment["APP_APPEARANCE"] ?? "dark"
                let renderer = ImageRenderer(content: display.frame(width: 1040, height: 760)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                    .environment(\.colorScheme, mode == "light" ? .light : .dark))
                renderer.scale = 2
                return renderer.nsImage
            })
        }
    }
}
