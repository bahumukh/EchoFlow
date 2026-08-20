import Cocoa

class EchoflowDictionarySheetController: NSWindowController {
    
    private var jsonEditor: NSTextView!
    weak var delegate: EchoflowAppDelegate?
    
    convenience init(delegate: EchoflowAppDelegate) {
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 500),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: sheetWindow)
        self.delegate = delegate
        
        // Sheet appearance
        sheetWindow.titlebarAppearsTransparent = true
        sheetWindow.titleVisibility = .hidden
        sheetWindow.isOpaque = false
        sheetWindow.backgroundColor = NSColor.windowBackgroundColor
        
        buildUI(in: sheetWindow.contentView!)
    }
    
    private func buildUI(in view: NSView) {
        var y: CGFloat = 450
        
        let titleLabel = NSTextField(labelWithString: "Dictionary & Snippets")
        titleLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.frame = NSRect(x: 30, y: y, width: 400, height: 22)
        view.addSubview(titleLabel)
        y -= 25
        
        let descLabel = NSTextField(labelWithString: "Teach Echoflow your words and reusable phrases via JSON.")
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 30, y: y, width: 600, height: 20)
        view.addSubview(descLabel)
        y -= 20
        
        // JSON Editor
        let editorHeight: CGFloat = y - 70
        let scrollView = NSScrollView(frame: NSRect(x: 30, y: 70, width: 600, height: editorHeight))
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .bezelBorder
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: editorHeight))
        textView.isEditable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.minSize = NSSize(width: 0, height: editorHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        
        scrollView.documentView = textView
        view.addSubview(scrollView)
        jsonEditor = textView
        
        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked(_:)))
        cancelButton.frame = NSRect(x: 30, y: 20, width: 100, height: 30)
        cancelButton.bezelStyle = .rounded
        view.addSubview(cancelButton)
        
        let saveButton = NSButton(title: "Save Changes", target: self, action: #selector(saveClicked(_:)))
        saveButton.frame = NSRect(x: 500, y: 20, width: 130, height: 30)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        view.addSubview(saveButton)
    }
    
    func refreshJSONEditor() {
        guard let delegate = delegate else { return }
        let editorContent: [String: Any] = [
            "dictionary": delegate.dictionaryEntries,
            "snippets": delegate.snippetEntries
        ]
        if let data = try? JSONSerialization.data(withJSONObject: editorContent, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: data, encoding: .utf8) {
            jsonEditor.string = jsonString
        }
    }
    
    @objc private func cancelClicked(_ sender: NSButton) {
        guard let sheet = window, let parent = sheet.sheetParent else { return }
        parent.endSheet(sheet)
    }
    
    @objc private func saveClicked(_ sender: NSButton) {
        guard let delegate = delegate else { return }
        let jsonString = jsonEditor.string
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dict = parsed["dictionary"] as? [[String: Any]],
              let snips = parsed["snippets"] as? [[String: Any]] else {
            let alert = NSAlert()
            alert.messageText = "Invalid JSON"
            alert.informativeText = "Please ensure dictionary and snippets are valid JSON arrays."
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window!)
            return
        }
        
        delegate.settings["dictionary"] = dict
        delegate.settings["snippets"] = snips
        delegate.saveSettings()
        
        guard let sheet = window, let parent = sheet.sheetParent else { return }
        parent.endSheet(sheet)
    }
}
