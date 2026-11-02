import AppKit
import Observation
import OSLog
import ApplicationServices
import CraftVoiceCore
import CraftVoiceSpeech
import CraftVoiceIntegration

@Observable @MainActor final class VoiceRuntime {
    static let shared = VoiceRuntime()
    let controller: DictationController
    var inputStatus = "Globale Bedienung wird vorbereitet."
    var shortcutError: String?
    var shortcuts: ShortcutConfiguration
    var accessibilityGranted = false
    var postingGranted = false
    var inserting = false
    var clipboardPending = false
    var settingsTab = 0
    var autoInsert: Bool { didSet { preferences.set(autoInsert, forKey: "automaticInsertion") } }
    var clipboardFallback: Bool { didSet { preferences.set(clipboardFallback, forKey: "clipboardFallback") } }
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let keys = GlobalHotKeys()
    @ObservationIgnored private var keyManager: HotKeyConfigurationManager?
    @ObservationIgnored private let insertion = TextInsertion()
    @ObservationIgnored private var target: FocusTarget?
    @ObservationIgnored private var gesture = ShortcutGesture()
    @ObservationIgnored private var insertionTask: Task<Void, Never>?
    @ObservationIgnored private var focusTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var booted = false
    @ObservationIgnored private var requestShown = false
    @ObservationIgnored private var flight = UUID()
    @ObservationIgnored private var deliveryStatus = DeliveryStatus.local
    private static let log = Logger(subsystem: "app.craftvoice.desktop", category: "Integration")
    var busy: Bool { controller.busy || inserting }
    var modelURL: URL {
        let path = preferences.string(forKey: "localModelPath") ?? ""
        return path.isEmpty ? LocalModelLocation.defaultFolder() : URL(fileURLWithPath: path, isDirectory: true)
    }
    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        autoInsert = preferences.object(forKey: "automaticInsertion") as? Bool ?? true
        clipboardFallback = preferences.bool(forKey: "clipboardFallback")
        shortcuts = preferences.data(forKey: "globalShortcuts").flatMap { try? JSONDecoder().decode(ShortcutConfiguration.self, from: $0) } ?? ShortcutConfiguration()
        controller = DictationController(recorder: MicrophoneRecorder(), engine: LocalWhisperEngine())
        controller.onResult = { [weak self] text in self?.received(text) }
        controller.onEnd = { [weak self] in
            guard let self else { return }
            if self.controller.state != .completed { self.clearTarget() }
        }
    }
    func boot() {
        guard !booted else { return }; booted = true
        refreshPermissions()
        guard ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil else {
            inputStatus = ProcessInfo.processInfo.environment["APP_SNAPSHOT_STATE"] == "completed"
                ? InsertionOutcome.payloadPresent.message : "Diagnoseansicht – keine globale Eingabe."
            return
        }
        keyManager = HotKeyConfigurationManager(registrar: keys)
        keys.onEvent = { [weak self] action, pressed in
            guard let self else { return }
            Self.log.notice("Global shortcut action=\(action.rawValue) pressed=\(pressed) state=\(String(describing: self.controller.state), privacy: .public)")
            if self.inserting && pressed { return }
            self.perform(self.gesture.event(pressed: pressed, state: self.controller.state))
        }
        applyShortcuts(shortcuts)
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { @Sendable [weak self] _ in
                MainActor.assumeIsolated { self?.cancel() }
            })
        }
    }
    func refreshPermissions() { accessibilityGranted = AXIsProcessTrusted(); postingGranted = CGPreflightPostEventAccess() }
    func requestAccessibility() {
        guard !AXIsProcessTrusted() else { refreshPermissions(); return }
        requestShown = true
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refreshPermissions()
    }
    func requestPosting() {
        guard clipboardFallback, !CGPreflightPostEventAccess() else { refreshPermissions(); return }
        _ = CGRequestPostEventAccess()
        refreshPermissions()
    }
    func applyShortcuts(_ configuration: ShortcutConfiguration) {
        guard !busy else { return }
        do {
            try keyManager?.apply(configuration)
            shortcuts = configuration
            if booted && ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil {
                preferences.set(try JSONEncoder().encode(configuration), forKey: "globalShortcuts")
            }
            gesture.reset(); shortcutError = nil
            inputStatus = "Tastenkürzel bereit: \(configuration.toggle.title)"
            Self.log.notice("Global shortcuts registered")
        } catch {
            shortcutError = error.localizedDescription
            Self.log.error("Global shortcut registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    func toggleGlobal() {
        if controller.state == .recording { stop() }
        else if controller.state == .preparing { cancel() }
        else if !busy { start(external: true) }
    }
    func startLocal() { if !busy { start(external: false) } }
    func stop() { controller.stop() }
    func cancel() {
        flight = UUID(); insertionTask?.cancel(); insertionTask = nil
        controller.cancel(); gesture.reset(); clearTarget()
        // An already posted paste is never retried or declared undone by cancelling.
        inputStatus = "Abgebrochen. Bereits versandte Eingaben bitte in der Zielanwendung prüfen."
    }
    private func perform(_ command: DictationCommand) {
        switch command {
        case .start: start(external: true)
        case .stop: stop()
        case .cancel: cancel()
        case .none: break
        }
    }
    private func start(external: Bool) {
        guard !busy else { return }
        clearTarget(); flight = UUID()
        if external && autoInsert {
            refreshPermissions()
            if !accessibilityGranted && !requestShown { requestAccessibility() }
            switch FocusTarget.captureResult() {
            case .success(let captured):
                target = captured; deliveryStatus = .captured
                Self.log.notice("External target captured; app=\(captured.applicationIdentifier, privacy: .public) pid=\(captured.pid) role=\(captured.capturedRole, privacy: .public) direct=\(captured.direct) keyboardAvailable=\(captured.canPost) webContext=\(captured.webContextVerified)")
            case .failure(let reason):
                deliveryStatus = .unavailable(reason.message)
                Self.log.error("External target capture failed: \(reason.rawValue, privacy: .public)")
            }
            inputStatus = deliveryStatus.message
            if let target {
                focusTask = Task { [weak self, weak target] in
                    while !Task.isCancelled {
                        guard let target else { return }
                        if !target.matchesOriginal() {
                            target.invalidate()
                            self?.inputStatus = "Zielwechsel erkannt. Der Text bleibt in CraftVoice."
                            return
                        }
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
            }
        } else {
            deliveryStatus = external ? .disabled : .local
            inputStatus = deliveryStatus.message
            Self.log.notice("Local delivery: external=\(external) automaticInsertion=\(self.autoInsert)")
        }
        controller.start(model: modelURL)
    }
    private func received(_ text: String) {
        LocalDiagnosticCapture.text(text, name: "controller-text.txt")
        focusTask?.cancel(); focusTask = nil
        guard let target else { inputStatus = deliveryStatus.retainedResultMessage; return }
        let id = flight
        let allowClipboard = clipboardFallback
        inserting = true
        insertionTask = Task { [weak self] in
            guard let self else { return }
            var ticket = InsertionTicket(id: id)
            let outcome = await self.insertion.insert(text, target: target, ticket: &ticket, allowClipboard: allowClipboard)
            target.stop()
            Self.log.notice("Insertion outcome=\(String(describing: outcome), privacy: .public)")
            if self.flight == id {
                self.inputStatus = outcome.message
                self.target = nil
            }
            self.clipboardPending = self.insertion.pendingClipboard != nil
            self.inserting = false
        }
    }
    func restoreClipboard() {
        inputStatus = insertion.restoreClipboard() ? "Vorherige Zwischenablage wiederhergestellt." : "Zwischenablage inzwischen geändert; nichts überschrieben."
        clipboardPending = insertion.pendingClipboard != nil
    }
    private func clearTarget() { focusTask?.cancel(); focusTask = nil; target?.stop(); target = nil }
    func shutdown() {
        cancel(); keyManager?.stop()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }
}
