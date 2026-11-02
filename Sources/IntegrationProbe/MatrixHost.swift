import AppKit
import SwiftUI
import WebKit
import Observation

@Observable @MainActor final class MatrixSwiftModel {
    var field = ""
    var editor = ""
    var focus: String?
}
struct MatrixSwiftFields: View {
    @Bindable var model: MatrixSwiftModel
    @FocusState private var focused: String?
    var body: some View {
        VStack(alignment: .leading) {
            TextField("SwiftUI TextField", text: $model.field).accessibilityIdentifier("MatrixSwiftField").focused($focused, equals: "swiftField")
            TextEditor(text: $model.editor).frame(height: 52).accessibilityIdentifier("MatrixSwiftEditor").focused($focused, equals: "swiftEditor")
        }.padding(8).onChange(of: model.focus) { _, value in focused = value }
    }
}

@MainActor final class MatrixHost: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    let stateURL: URL
    let field = NSTextField(string: "")
    let search = NSSearchField(string: "")
    let editor = NSTextView()
    let model = MatrixSwiftModel()
    var web: WKWebView!
    var window: NSWindow!
    var active = ""
    var ready = false
    var webValues: [String: String] = [:]
    var timer: Timer?
    init(stateURL: URL) { self.stateURL = stateURL }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let main = NSMenu()
        let application = NSMenuItem(); main.addItem(application)
        let applicationMenu = NSMenu(); application.submenu = applicationMenu
        applicationMenu.addItem(withTitle: "Testhost beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenuItem(); main.addItem(edit)
        let editMenu = NSMenu(title: "Bearbeiten"); edit.submenu = editMenu
        for (title, action, key) in [("Ausschneiden", "cut:", "x"), ("Kopieren", "copy:", "c"), ("Einsetzen", "paste:", "v"), ("Alles auswählen", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        NSApp.mainMenu = main
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "matrix")
        web = WKWebView(frame: .zero, configuration: config); web.navigationDelegate = self
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.addArrangedSubview(NSTextField(labelWithString: "CraftVoice – lokale Kompatibilitätsmatrix (nur synthetische Testdaten)"))
        for (view, name) in [(field, "MatrixNativeField"), (search as NSTextField, "MatrixNativeSearch")] {
            view.setAccessibilityIdentifier(name); view.placeholderString = name
            view.widthAnchor.constraint(equalToConstant: 720).isActive = true
            stack.addArrangedSubview(view)
        }
        editor.isRichText = false; editor.setAccessibilityIdentifier("MatrixNativeEditor")
        let scroll = NSScrollView(); scroll.documentView = editor; scroll.hasVerticalScroller = true
        scroll.widthAnchor.constraint(equalToConstant: 720).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 56).isActive = true
        stack.addArrangedSubview(scroll)
        let swift = NSHostingView(rootView: MatrixSwiftFields(model: model))
        swift.widthAnchor.constraint(equalToConstant: 720).isActive = true
        stack.addArrangedSubview(swift)
        web.widthAnchor.constraint(equalToConstant: 720).isActive = true
        web.heightAnchor.constraint(equalToConstant: 310).isActive = true
        stack.addArrangedSubview(web)
        window = NSWindow(contentRect: NSRect(x: 120, y: 80, width: 760, height: 660), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "CraftVoice – eigene Kompatibilitätstests"
        window.contentView = stack; window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        web.loadHTMLString(Self.html, baseURL: URL(string: "https://craftvoice.invalid/"))
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.command(); self?.writeState() }
        }
        writeState()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; writeState() }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let payload = message.body as? [String: String], let id = payload["id"], let value = payload["value"] else { return }
        webValues[id] = value
        if payload["focused"] == "true" { active = id }
        writeState()
    }
    func command() {
        let path = stateURL.appendingPathExtension("command")
        guard let data = try? Data(contentsOf: path), let args = try? JSONSerialization.jsonObject(with: data) as? [String: String], let id = args["focus"] else { return }
        try? FileManager.default.removeItem(at: path)
        if id.hasPrefix("html") {
            guard ["htmlText", "htmlSearch", "htmlArea", "htmlEditable"].contains(id) else { return }
            active = ""; webValues[id] = ""
            window.makeFirstResponder(web)
            web.evaluateJavaScript("matrixFocus('" + id + "')", completionHandler: nil)
            return
        }
        switch id {
        case "nativeField": field.stringValue = ""; window.makeFirstResponder(field)
        case "nativeSearch": search.stringValue = ""; window.makeFirstResponder(search)
        case "nativeEditor": editor.string = ""; window.makeFirstResponder(editor)
        case "swiftField", "swiftEditor":
            model.field = ""; model.editor = ""
            model.focus = nil
            DispatchQueue.main.async { [weak self] in self?.model.focus = id; self?.active = id }
            return
        default: return
        }
        active = id
    }
    func nativeValue(_ view: NSTextField) -> String { view.currentEditor()?.string ?? view.stringValue }
    func writeState() {
        let values = ["nativeField": nativeValue(field), "nativeSearch": nativeValue(search), "nativeEditor": editor.string,
            "swiftField": model.field, "swiftEditor": model.editor].merging(webValues) { _, new in new }
        let state: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier, "ready": ready, "active": active, "values": values]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: .sortedKeys) { try? data.write(to: stateURL, options: .atomic) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate() }
    static let html = """
    <!doctype html><meta charset="utf-8"><style>body{font:14px system-ui;margin:8px}input,textarea,[contenteditable]{box-sizing:border-box;width:96%;margin:3px;padding:4px;border:1px solid #777}textarea{height:48px}[contenteditable]{min-height:40px}</style>
    <label>HTML Text<input id="htmlText" aria-label="Matrix HTML Text"></label>
    <label>HTML Suche / editierbare Combobox<input id="htmlSearch" type="search" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-label="Matrix HTML Search"></label>
    <label>HTML Textarea<textarea id="htmlArea" aria-label="Matrix HTML Textarea"></textarea></label>
    <div id="htmlEditable" contenteditable="true" role="textbox" aria-multiline="true" aria-label="Matrix Contenteditable"></div>
    <script>
    function report(e){let n=e.target;window.webkit.messageHandlers.matrix.postMessage({id:n.id,value:n.isContentEditable?n.innerText:n.value,focused:String(document.activeElement===n)})}
    document.querySelectorAll('input,textarea,[contenteditable]').forEach(n=>{n.addEventListener('input',report);n.addEventListener('focus',report)})
    function matrixFocus(id){let n=document.getElementById(id);if(n.isContentEditable)n.innerText='';else n.value='';n.focus();n.scrollIntoView();report({target:n})}
    </script>
    """
}
