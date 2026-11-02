import AppKit
import ApplicationServices
import CraftVoiceCore
import CraftVoiceIntegration

@MainActor final class Host: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    let stateURL: URL
    let first = NSTextView()
    let second = NSTextView()
    let keys = GlobalHotKeys()
    var window: NSWindow?
    var events: [[String: Any]] = []
    var timer: Timer?
    var keyError: String?
    init(stateURL: URL) { self.stateURL = stateURL }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 120, y: 120, width: 640, height: 400),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "CraftVoice – eigener Integrationstest"
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.addArrangedSubview(NSTextField(labelWithString: "Nur synthetische Testfelder – kein Mikrofon und keine Modelldownloads."))
        for (index, view) in [first, second].enumerated() {
            view.string = index == 0 ? "Vorher nachher" : "Zweites Feld"
            view.isRichText = false; view.isEditable = true; view.font = .systemFont(ofSize: 16)
            view.delegate = self; view.setAccessibilityIdentifier("CraftVoiceTestField\(index + 1)")
            let scroll = NSScrollView(); scroll.documentView = view; scroll.hasVerticalScroller = true
            scroll.borderType = .bezelBorder
            scroll.widthAnchor.constraint(equalToConstant: 600).isActive = true
            scroll.heightAnchor.constraint(equalToConstant: 120).isActive = true
            stack.addArrangedSubview(scroll)
        }
        stack.addArrangedSubview(NSTextField(labelWithString: "Tastentest: ⌃⌥⇧⌘F12"))
        window.contentView = stack; self.window = window
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(first)
        first.setSelectedRange(NSRange(location: 7, length: 0))
        NSApp.activate()
        keys.onEvent = { [weak self] action, pressed in
            self?.events.append(["action": action.rawValue, "pressed": pressed]); self?.writeState()
        }
        do {
            try keys.register(GlobalShortcut(key: .f12, command: true, shift: true), action: .toggle)
        } catch { keyError = error.localizedDescription }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.readCommand() }
        }
        writeState()
    }
    func textDidChange(_ notification: Notification) { writeState() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { keys.unregisterAll(); timer?.invalidate() }
    func writeState() {
        let payload: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier,
            "first": first.string, "second": second.string, "events": events,
            "keyError": keyError ?? ""]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }
    func readCommand() {
        let commandURL = stateURL.appendingPathExtension("command")
        guard let data = try? Data(contentsOf: commandURL), let command = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else { return }
        try? FileManager.default.removeItem(at: commandURL)
        if command["redundant"] == 1 {
            NSAccessibility.post(element: first, notification: .selectedTextChanged)
            return
        }
        if command["readonly"] == 1 { second.isEditable = false }
        if command["focus"] == 2 { window?.makeFirstResponder(second) }
        else { window?.makeFirstResponder(first) }
        writeState()
    }
}

@main @MainActor struct IntegrationProbe {
    static func emit(_ message: String) { FileHandle.standardOutput.write(Data((message + "\n").utf8)) }
    static func main() {
        let matrixURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("checks/universal-matrix-state.json")
        if CommandLine.arguments.contains("--matrix-host") {
            let app = NSApplication.shared; app.setActivationPolicy(.regular)
            let host = MatrixHost(stateURL: matrixURL); app.delegate = host
            withExtendedLifetime(host) { app.run() }; return
        }
        if CommandLine.arguments.contains("--matrix-client") {
            Task { await MatrixDriver.run(stateURL: matrixURL, allowClipboard: CommandLine.arguments.contains("--matrix-allow-clipboard")) }
            RunLoop.main.run(); return
        }
        if CommandLine.arguments.contains("--diagnose-focus") {
            emit("accessibility=\(AXIsProcessTrusted()) posting=\(CGPreflightPostEventAccess())")
            switch FocusTarget.captureResult() {
            case .success(let target):
                emit("capture=success direct=\(target.direct) original=\(target.matchesOriginal())")
                target.stop()
            case .failure(let reason): emit("capture=\(reason.rawValue): \(reason.message)")
            }
            return
        }
        let args = CommandLine.arguments
        let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("checks")
        if args.contains("--selftest") || args.contains("--client") {
            // A CLI test driver must not create/activate NSApplication and steal the host focus.
            Task { await runSelftest(folder: folder) }
            RunLoop.main.run()
        } else {
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            let path = args.dropFirst().first(where: { !$0.hasPrefix("--") }).map { URL(fileURLWithPath: $0) }
                ?? (Bundle.main.object(forInfoDictionaryKey: "CraftVoiceTestStatePath") as? String).map { URL(fileURLWithPath: $0) }
                ?? folder.appendingPathComponent("phase3-host-state.json")
            let host = Host(stateURL: path); app.delegate = host
            withExtendedLifetime(host) { app.run() }
        }
    }
    static func runSelftest(folder: URL) async {
        guard AXIsProcessTrusted() else { emit("SKIP native AX test: existing Accessibility permission unavailable; no request or reset performed"); exit(2) }
        let external = CommandLine.arguments.contains("--client")
        let path = folder.appendingPathComponent(external ? "phase3-host-state.json" : "phase3-selftest-host.json")
        var child: Process?
        let expectedPID: pid_t
        if external {
            guard let data = try? Data(contentsOf: path),
                  let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = state["pid"] as? Int,
                  NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier == "app.craftvoice.desktop.integrationtest" else {
                emit("FAIL authorized own test host missing"); exit(1)
            }
            expectedPID = pid_t(pid)
        } else {
            let process = Process(); process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]); process.arguments = [path.path]
            do { try process.run() } catch { emit("FAIL start own host: \(error)"); exit(1) }
            child = process; expectedPID = process.processIdentifier
        }
        func finish(_ code: Int32) -> Never { if let child, child.isRunning { child.terminate() }; exit(code) }
        do {
            for _ in 0..<100 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == expectedPID { break }
                try await Task.sleep(for: .milliseconds(50))
            }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == expectedPID else { emit("FAIL own host not foreground; no input dispatched"); finish(1) }
            try await Task.sleep(for: .milliseconds(200))
            guard let target = FocusTarget.capture(), target.pid == expectedPID else { emit("FAIL own field not securely captured"); finish(1) }
            try JSONSerialization.data(withJSONObject: ["redundant": 1]).write(to: path.appendingPathExtension("command"), options: .atomic)
            try await Task.sleep(for: .milliseconds(200))
            guard target.matchesOriginal() else { emit("FAIL redundant AX notification invalidated unchanged target"); finish(1) }
            emit("PASS redundant AX notification preserves unchanged target")
            let clipboardCount = NSPasteboard.general.changeCount
            var ticket = InsertionTicket()
            let service = TextInsertion()
            let result = await service.insert("Testtext ", target: target, ticket: &ticket, allowClipboard: false)
            target.stop()
            guard result == .inserted, NSPasteboard.general.changeCount == clipboardCount else { emit("FAIL native AX insertion: \(result)"); finish(1) }
            emit("PASS native AX insertion into separate own test process; general clipboard unchanged")
            let repeated = await service.insert("Doppelt", target: target, ticket: &ticket, allowClipboard: false)
            guard repeated == .blocked else { emit("FAIL duplicate insertion"); finish(1) }
            emit("PASS native duplicate prevented")
            guard let changed = FocusTarget.capture(), changed.pid == expectedPID else { emit("FAIL second capture"); finish(1) }
            try JSONSerialization.data(withJSONObject: ["focus": 2]).write(to: path.appendingPathExtension("command"), options: .atomic)
            try await Task.sleep(for: .milliseconds(250))
            var changedTicket = InsertionTicket()
            let blocked = await service.insert("Nicht einfügen", target: changed, ticket: &changedTicket, allowClipboard: false)
            changed.stop()
            guard blocked == .blocked else { emit("FAIL focus guard"); finish(1) }
            emit("PASS native focus change blocked")
            guard let readonly = FocusTarget.capture(), readonly.pid == expectedPID else { emit("FAIL read-only test capture"); finish(1) }
            try JSONSerialization.data(withJSONObject: ["focus": 2, "readonly": 1]).write(to: path.appendingPathExtension("command"), options: .atomic)
            try await Task.sleep(for: .milliseconds(250))
            var readonlyTicket = InsertionTicket()
            let refused = await service.insert("Nicht einfügen", target: readonly, ticket: &readonlyTicket, allowClipboard: false)
            readonly.stop()
            guard refused == .blocked else { emit("FAIL newly read-only field accepted"); finish(1) }
            emit("PASS newly read-only field blocked")
            finish(0)
        } catch { emit("FAIL native integration: \(error)"); finish(1) }
    }
}
