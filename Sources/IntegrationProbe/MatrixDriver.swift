import AppKit
import ApplicationServices
import CraftVoiceCore
import CraftVoiceIntegration

@MainActor enum MatrixDriver {
    static func run(stateURL: URL, allowClipboard: Bool) async {
        func read() -> [String: Any]? {
            guard let data = try? Data(contentsOf: stateURL) else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        guard let state = read(), let number = state["pid"] as? Int,
              let app = NSRunningApplication(processIdentifier: pid_t(number)),
              app.bundleIdentifier == "app.craftvoice.desktop.integrationtest" else { IntegrationProbe.emit("FAIL own signed matrix host unavailable"); exit(2) }
        let pid = app.processIdentifier
        for _ in 0..<600 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard AXIsProcessTrusted(), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            IntegrationProbe.emit("BLOCKED own matrix host is not foreground or Accessibility unavailable; no input dispatched"); exit(2)
        }
        let short = "Grüße aus Köln – Maßprüfung 12,5 mm! 😀"
        let cases: [(String, String, Bool)] = [
            ("nativeField", short, false), ("nativeSearch", short, false), ("nativeEditor", short, false),
            ("swiftField", short, false), ("swiftEditor", short, false),
            ("htmlText", short, false), ("htmlSearch", short, false), ("htmlArea", short, false), ("htmlEditable", short, false),
            ("nativeEditor", "Erste Zeile\nZweite Zeile: Grüße 😀", false),
            ("htmlArea", "Erste Zeile\nZweite Zeile: Grüße 😀", allowClipboard),
            ("htmlEditable", "Erste Zeile\nZweite Zeile: Grüße 😀", allowClipboard),
            ("nativeEditor", String(repeating: "Grüße – 123,5 mm! 😀 ", count: 100), false),
            ("htmlArea", String(repeating: "Grüße – 123,5 mm! 😀 ", count: 100), false)]
        var passed = 0, failed = 0, skipped = 0
        func safeCleanup(_ service: TextInsertion) async {
            guard service.pendingClipboard != nil else { return }
            // Only our synthetic host can consume this test paste. Stop that host
            // before restoring an unconfirmed transaction; never discard the snapshot.
            _ = app.terminate()
            for _ in 0..<40 {
                if app.isTerminated { break }
                try? await Task.sleep(for: .milliseconds(25))
            }
            if !app.isTerminated { _ = app.forceTerminate() }
            while !app.isTerminated { try? await Task.sleep(for: .milliseconds(50)) }
            IntegrationProbe.emit("CLEANUP own host stopped; pending test clipboard restored=\(service.restoreClipboard())")
        }
        for (id, text, clipboard) in cases {
            if clipboard && NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "“”\""))) != "CraftVoice Clipboard Matrix 2026" {
                IntegrationProbe.emit("SKIP real clipboard case: explicitly disposable baseline missing"); skipped += 1; continue
            }
            var activeService: TextInsertion?
            do {
                try JSONSerialization.data(withJSONObject: ["focus": id]).write(to: stateURL.appendingPathExtension("command"), options: .atomic)
                var focused = false
                for _ in 0..<40 {
                    try await Task.sleep(for: .milliseconds(50))
                    let current = read()
                    if current?["active"] as? String == id, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                        focused = true; break
                    }
                }
                guard focused else { IntegrationProbe.emit("FAIL matrix focus prerequisite \(id)"); failed += 1; continue }
                try await Task.sleep(for: .milliseconds(150))
                var captured: FocusTarget?
                var failure = "not ready"
                for _ in 0..<40 {
                    let result = FocusTarget.captureResult(expectedPID: pid)
                    switch result {
                    case .success(let target):
                        if target.originalValue.isEmpty { captured = target }
                        else { target.stop(); failure = "initial value not empty" }
                    case .failure(let reason): failure = reason.rawValue
                    }
                    if captured != nil { break }
                    try await Task.sleep(for: .milliseconds(50))
                }
                guard let target = captured else {
                    IntegrationProbe.emit("FAIL matrix capture \(id): \(failure)"); failed += 1; continue
                }
                let service = TextInsertion(); activeService = service
                var ticket = InsertionTicket()
                let result = await service.insert(text, target: target, ticket: &ticket, allowClipboard: clipboard)
                var actual = ""
                for _ in 0..<80 {
                    actual = (read()?["values"] as? [String: String])?[id] ?? ""
                    if actual == text { break }
                    try await Task.sleep(for: .milliseconds(25))
                }
                let duplicate = await service.insert(text, target: target, ticket: &ticket, allowClipboard: clipboard)
                if actual == text, duplicate == .blocked {
                    if service.pendingClipboard != nil { _ = service.restoreClipboard() } // independent own-view proof
                    IntegrationProbe.emit("PASS real \(id) utf16=\(text.utf16.count) result=\(result) exactOwnView=true duplicateBlocked=true")
                    passed += 1
                } else {
                    IntegrationProbe.emit("FAIL real \(id) utf16=\(text.utf16.count) observedUtf16=\(actual.utf16.count) result=\(result)")
                    failed += 1
                    if service.pendingClipboard != nil {
                        await safeCleanup(service); target.stop(); exit(1)
                    }
                }
                target.stop()
            } catch {
                if let service = activeService, service.pendingClipboard != nil { await safeCleanup(service); exit(1) }
                IntegrationProbe.emit("FAIL matrix local operation"); failed += 1
            }
        }
        IntegrationProbe.emit("Clipboard disposable baseline restored=\(NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "“”\""))) == "CraftVoice Clipboard Matrix 2026")")
        IntegrationProbe.emit("MATRIX real passed=\(passed) failed=\(failed) skipped=\(skipped); no microphone/models/network")
        exit(failed == 0 ? 0 : 1)
    }
}
private extension Result where Failure == FocusTarget.CaptureFailure {
    var failureName: String {
        switch self { case .failure(let failure): failure.rawValue; case .success: "unexpected initial value or PID" }
    }
}
