import AppKit
import ApplicationServices
import Carbon
import Darwin
import CraftVoiceCore

@MainActor public enum AXRead {
    public static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success ? result : nil
    }
    public static func element(_ root: AXUIElement, _ key: String) -> AXUIElement? {
        guard let result = value(root, key), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }
    public static func range(_ field: AXUIElement) -> CFRange? {
        guard let raw = value(field, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let val = raw as! AXValue
        guard AXValueGetType(val) == .cfRange else { return nil }
        var range = CFRange()
        return AXValueGetValue(val, .cfRange, &range) ? range : nil
    }
    public static func settable(_ field: AXUIElement, _ key: String) -> Bool {
        var result = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(field, key as CFString, &result) == .success && result.boolValue
    }
    public static func secure(_ field: AXUIElement) -> Bool {
        (value(field, kAXSubroleAttribute) as? String) == kAXSecureTextFieldSubrole
            || (value(field, "AXProtectedContent") as? Bool) == true || IsSecureEventInputEnabled()
    }
}

/// Kernel process birth time also covers apps started directly from a development bundle.
/// A recycled PID is never treated as the original process.
public struct ProcessBirth: Equatable, Sendable {
    let seconds: UInt64
    let microseconds: UInt64
    public static func read(_ pid: pid_t) -> ProcessBirth? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size else { return nil }
        return ProcessBirth(seconds: info.pbi_start_tvsec, microseconds: info.pbi_start_tvusec)
    }
}

/// Holds only the originally focused field. No titles, text, or clipboard data are logged.
@MainActor public final class FocusTarget: InsertionTargetAccess {
    public let pid: pid_t
    public let birth: ProcessBirth
    public let field: AXUIElement
    public let window: AXUIElement
    public let originalValue: String
    public let selection: CFRange
    public let direct: Bool
    public var acceptsNewlines: Bool { fieldRole == kAXTextAreaRole }
    public let applicationIdentifier: String
    private let unicodeDocument: String?
    private let fieldRole: String
    private let webContext: WebEditorContext?
    public var webContextVerified: Bool { webContext != nil }
    public var capturedRole: String { fieldRole }
    private var continuity = FocusContinuity()
    private var lastDiagnosticValue: String?
    public var invalidated: Bool { continuity.invalidated }
    private let app: AXUIElement
    private var observer: AXObserver?
    private var monitored: [(AXUIElement, String)] = []
    private var workspaceToken: NSObjectProtocol?

    public enum CaptureFailure: String, Error, CaseIterable, Sendable {
        case permission, secureInput, application, field, window, role, disabled, value, selection, editable, owner, monitoring, changed
        public var message: String {
            switch self {
            case .permission: "Bedienungshilfen sind für diesen CraftVoice-Prozess nicht erlaubt."
            case .secureInput: "Geschütztes Eingabefeld oder sichere Tastatureingabe aktiv."
            case .application: "Keine andere aktive Zielanwendung."
            case .field: "Die Zielanwendung meldet kein fokussiertes Eingabefeld."
            case .window: "Das ursprüngliche Zielfenster ist nicht prüfbar."
            case .role: "Der Fokus liegt nicht in einem unterstützten Textfeld."
            case .disabled: "Das Zieltextfeld ist deaktiviert."
            case .value: "Der ursprüngliche Feldinhalt ist nicht sicher prüfbar."
            case .selection: "Die ursprüngliche Einfügeposition ist nicht sicher prüfbar."
            case .editable: "Das Zieltextfeld meldet keine Schreibfähigkeit."
            case .owner: "Das Textfeld gehört nicht zur aktiven Zielanwendung."
            case .monitoring: "Fokusänderungen der Zielanwendung sind nicht sicher überwachbar."
            case .changed: "Das Zieltextfeld hat sich während der Erfassung geändert."
            }
        }
    }
    public static func capture(excluding ownPID: pid_t = ProcessInfo.processInfo.processIdentifier, expectedPID: pid_t? = nil) -> FocusTarget? {
        try? captureResult(excluding: ownPID, expectedPID: expectedPID).get()
    }
    public static func captureResult(excluding ownPID: pid_t = ProcessInfo.processInfo.processIdentifier, expectedPID: pid_t? = nil) -> Result<FocusTarget, CaptureFailure> {
        guard AXIsProcessTrusted() else { return .failure(.permission) }
        guard !IsSecureEventInputEnabled() else { return .failure(.secureInput) }
        guard let running = NSWorkspace.shared.frontmostApplication,
              running.processIdentifier != ownPID, let birth = ProcessBirth.read(running.processIdentifier) else { return .failure(.application) }
        guard expectedPID == nil || expectedPID == running.processIdentifier else { return .failure(.application) }
        let app = AXUIElementCreateApplication(running.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.25)
        guard let field = AXRead.element(app, kAXFocusedUIElementAttribute) else { return .failure(.field) }
        guard let window = AXRead.element(app, kAXFocusedWindowAttribute) else { return .failure(.window) }
        guard !AXRead.secure(field) else { return .failure(.secureInput) }
        guard let role = AXRead.value(field, kAXRoleAttribute) as? String,
              [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) else { return .failure(.role) }
        guard (AXRead.value(field, kAXEnabledAttribute) as? Bool) != false else { return .failure(.disabled) }
        guard let value = AXRead.value(field, kAXValueAttribute) as? String, value.utf16.count <= 262_144 else { return .failure(.value) }
        guard let selection = AXRead.range(field),
              ExpectedInsertion.replacing(value: value, location: selection.location, length: selection.length, text: "") != nil else { return .failure(.selection) }
        let selectedTextSettable = AXRead.settable(field, kAXSelectedTextAttribute)
        let valueSettable = AXRead.settable(field, kAXValueAttribute)
        let editable = (AXRead.value(field, "AXEditable") as? Bool) == true
        guard InputPolicy.editable(role: role, selectedTextWritable: selectedTextSettable, valueWritable: valueSettable,
            editable: editable, selectionWritable: AXRead.settable(field, kAXSelectedTextRangeAttribute)) else { return .failure(.editable) }
        var owner: pid_t = 0
        guard AXUIElementGetPid(field, &owner) == .success, owner == running.processIdentifier else { return .failure(.owner) }
        let document = AXRead.value(window, kAXDocumentAttribute) as? String
        let webContext = WebEditorContext.capture(field: field)
        let target = FocusTarget(pid: owner, birth: birth, app: app, field: field, window: window, value: value, selection: selection,
            applicationIdentifier: running.bundleIdentifier ?? "unknown", unicodeDocument: document,
            direct: selectedTextSettable, role: role, webContext: webContext)
        guard target.startMonitoring() else { target.stop(); return .failure(.monitoring) }
        guard target.matchesOriginal() else { target.stop(); return .failure(.changed) }
        return .success(target)
    }
    private init(pid: pid_t, birth: ProcessBirth, app: AXUIElement, field: AXUIElement, window: AXUIElement, value: String, selection: CFRange, applicationIdentifier: String, unicodeDocument: String?, direct: Bool, role: String, webContext: WebEditorContext?) {
        self.pid = pid; self.birth = birth; self.app = app; self.field = field; self.window = window
        self.originalValue = value; self.selection = selection
        self.applicationIdentifier = applicationIdentifier; self.unicodeDocument = unicodeDocument
        self.direct = direct; self.fieldRole = role; self.webContext = webContext
    }
    public var insertionRange: NSRange { NSRange(location: selection.location, length: selection.length) }
    public var allowed: Bool { AXIsProcessTrusted() }
    public var secureInput: Bool { IsSecureEventInputEnabled() || AXRead.secure(field) }
    public var canPost: Bool { CGPreflightPostEventAccess() }
    public func writeSelectedText(_ text: String) -> DirectWriteResult {
        guard matchesOriginal(), allowed, !secureInput else { return .blocked }
        return DirectWriteResult.classify(AXUIElementSetAttributeValue(field, kAXSelectedTextAttribute as CFString, text as CFString))
    }
    public func postUnicode(_ text: String) -> UnicodeDispatchResult {
        guard canPost, matchesOriginal(), !secureInput, let events = UnicodeInputPayload.events(text) else { return .notSent }
        var sent = false
        var sentUnits: [UniChar] = []
        defer { LocalDiagnosticCapture.text(String(decoding: sentUnits, as: UTF16.self), name: "queued-unicode.txt") }
        for (down, up) in events {
            guard !Task.isCancelled, allowed, canPost, matchesIdentity(), !secureInput,
                  sent || matchesOriginal() else { return sent ? .partial : .notSent }
            // Route to the captured process only. No activation, global posting, or Return.
            down.postToPid(pid); up.postToPid(pid); sent = true
            sentUnits.append(contentsOf: UnicodeInputPayload.payload(down))
        }
        return .posted
    }
    public func postPaste() -> Bool {
        guard canPost, matchesOriginal(), !secureInput,
              let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { return false }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.postToPid(pid); up.postToPid(pid)
        return true
    }
    public func matchesIdentity() -> Bool {
        if let webContext, !webContext.matches(field: field) { return false }
        guard (AXRead.value(field, kAXRoleAttribute) as? String) == fieldRole,
              InputPolicy.sameDocument(unicodeDocument, AXRead.value(window, kAXDocumentAttribute) as? String) else { return false }
        guard AXIsProcessTrusted(), !AXRead.secure(field),
              (AXRead.value(field, kAXEnabledAttribute) as? Bool) != false,
              AXRead.settable(field, kAXSelectedTextAttribute) || AXRead.settable(field, kAXValueAttribute)
                || (AXRead.value(field, "AXEditable") as? Bool) == true,
              let current = NSWorkspace.shared.frontmostApplication, current.processIdentifier == pid,
              !current.isTerminated, ProcessBirth.read(pid) == birth,
              let focused = AXRead.element(app, kAXFocusedUIElementAttribute), CFEqual(focused, field),
              let focusedWindow = AXRead.element(app, kAXFocusedWindowAttribute), CFEqual(focusedWindow, window) else { return false }
        return true
    }
    public func matchesOriginal() -> Bool {
        guard !invalidated, matchesIdentity(), let range = AXRead.range(field),
              range.location == selection.location, range.length == selection.length,
              (AXRead.value(field, kAXValueAttribute) as? String) == originalValue else { return false }
        return true
    }
    public func observeInsertion(expected: String, inserted: String) -> InsertionReadback {
        // Read only the captured element. Current focus gates writes, not proof of an
        // already completed write. Never search for a replacement/current field here.
        guard AXIsProcessTrusted(), ProcessBirth.read(pid) == birth, !AXRead.secure(field) else { return .targetLost }
        var owner: pid_t = 0
        guard AXUIElementGetPid(field, &owner) == .success, owner == pid else { return .targetLost }
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &raw)
        guard status == .success else { return .unreadable(status.rawValue) }
        let value = raw as? String
        if let value, value != lastDiagnosticValue {
            LocalDiagnosticCapture.text(value, name: "readback-latest.txt")
            lastDiagnosticValue = value
        }
        return InsertionReadback.compare(value: value, original: originalValue, expected: expected, inserted: inserted)
    }
    public func invalidate() { continuity.observe(matchesOriginal: false) }
    private func observeNotification(element: AXUIElement, name: CFString) {
        let destroyed = (name as String) == kAXUIElementDestroyedNotification && CFEqual(element, field)
        // Chromium and native editors can send redundant selection/focus notifications.
        // Validate the captured identity and original contents before latching rejection.
        continuity.observe(matchesOriginal: matchesOriginal(), destroyed: destroyed)
    }
    private func startMonitoring() -> Bool {
        var result: AXObserver?
        guard AXObserverCreate(pid, { _, element, name, context in
            guard let context else { return }
            // Source is explicitly installed on the main run loop below.
            MainActor.assumeIsolated { Unmanaged<FocusTarget>.fromOpaque(context).takeUnretainedValue().observeNotification(element: element, name: name) }
        }, &result) == .success, let result else { return false }
        observer = result
        for (element, name) in [(app, kAXFocusedUIElementChangedNotification), (app, kAXFocusedWindowChangedNotification),
                                (field, kAXSelectedTextChangedNotification), (field, kAXValueChangedNotification),
                                (field, kAXUIElementDestroyedNotification)] {
            let status = AXObserverAddNotification(result, element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
            if status == .success { monitored.append((element, name)) }
            else if name == kAXFocusedUIElementChangedNotification || name == kAXFocusedWindowChangedNotification { stop(); return false }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(result), .commonModes)
        workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { @Sendable [weak self] note in
                let activated = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                MainActor.assumeIsolated { if activated != self?.pid { self?.invalidate() } }
            }
        return true
    }
    public func stop() {
        if let observer {
            for (element, name) in monitored { AXObserverRemoveNotification(observer, element, name as CFString) }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        monitored.removeAll(); observer = nil
        if let workspaceToken { NSWorkspace.shared.notificationCenter.removeObserver(workspaceToken) }
        workspaceToken = nil
    }
}
