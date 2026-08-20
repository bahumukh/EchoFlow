import Cocoa
import ServiceManagement

class EchoflowSettingsWindowController: NSWindowController {
    
    private var statusIndicator: NSTextField!
    private var statusDot: NSTextField!
    
    // Checkboxes
    private var pasteCheck: NSButton!
    private var audioCheck: NSButton!
    private var fillersCheck: NSButton!
    private var smartCheck: NSButton!
    private var launchAtLoginCheck: NSButton!
    
    private var dictionarySheetController: EchoflowDictionarySheetController!
    
    weak var delegate: EchoflowAppDelegate?
    
    convenience init(delegate: EchoflowAppDelegate) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        self.delegate = delegate
        
        window.title = "Echoflow Settings"
        window.center()
        
        // Glassmorphism Window Setup
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        let effectView = NSVisualEffectView(frame: window.contentView!.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .underWindowBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        window.contentView = effectView
        
        dictionarySheetController = EchoflowDictionarySheetController(delegate: delegate)
        
        buildUI(in: effectView)
    }
    
    private func buildUI(in view: NSView) {
        let padding: CGFloat = 40
        var y: CGFloat = 550
        
        // --- HEADER ---
        let headerLabel = NSTextField(labelWithString: "Echoflow")
        headerLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        headerLabel.frame = NSRect(x: padding, y: y, width: 300, height: 34)
        view.addSubview(headerLabel)
        
        statusDot = NSTextField(labelWithString: "●")
        statusDot.font = NSFont.systemFont(ofSize: 18)
        statusDot.textColor = .systemGreen
        statusDot.frame = NSRect(x: 760 - padding - 130, y: y + 4, width: 20, height: 24)
        view.addSubview(statusDot)
        
        statusIndicator = NSTextField(labelWithString: "Ready")
        statusIndicator.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        statusIndicator.textColor = .secondaryLabelColor
        statusIndicator.frame = NSRect(x: 760 - padding - 110, y: y + 6, width: 110, height: 20)
        view.addSubview(statusIndicator)
        
        y -= 25
        
        let instruction = NSTextField(labelWithString: "Speak naturally. Your audio stays on this Mac.")
        instruction.font = NSFont.systemFont(ofSize: 14)
        instruction.textColor = .secondaryLabelColor
        instruction.frame = NSRect(x: padding, y: y, width: 660, height: 20)
        view.addSubview(instruction)
        
        y -= 30
        addSeparator(in: view, at: y, padding: padding)
        y -= 30
        
        // --- 1. DICTATION ---
        addSectionHeader(in: view, title: "DICTATION", y: y, padding: padding)
        y -= 35
        
        let holdLabel = NSTextField(labelWithString: "Hold shortcut")
        holdLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        holdLabel.frame = NSRect(x: padding, y: y, width: 120, height: 20)
        view.addSubview(holdLabel)
        
        // Styled shortcut box
        let shortcutBox = NSView(frame: NSRect(x: 200, y: y - 2, width: 120, height: 24))
        shortcutBox.wantsLayer = true
        shortcutBox.layer?.cornerRadius = 6
        shortcutBox.layer?.borderColor = NSColor.separatorColor.cgColor
        shortcutBox.layer?.borderWidth = 1
        shortcutBox.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let shortcutText = NSTextField(labelWithString: "Fn")
        shortcutText.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        shortcutText.alignment = .center
        shortcutText.frame = NSRect(x: 0, y: 3, width: 120, height: 18)
        shortcutBox.addSubview(shortcutText)
        view.addSubview(shortcutBox)
        
        y -= 40
        
        pasteCheck = createCheckbox(title: "Paste into the active app", x: 200, y: y, width: 300, action: #selector(toggleSetting(_:)))
        view.addSubview(pasteCheck)
        y -= 30
        
        audioCheck = createCheckbox(title: "Keep source audio", x: 200, y: y, width: 300, action: #selector(toggleSetting(_:)))
        view.addSubview(audioCheck)
        
        y -= 40
        
        // --- 2. LANGUAGE & MODEL ---
        addSectionHeader(in: view, title: "LANGUAGE & MODEL", y: y, padding: padding)
        y -= 35
        
        let langLabel = NSTextField(labelWithString: "Language")
        langLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        langLabel.frame = NSRect(x: padding, y: y, width: 120, height: 20)
        view.addSubview(langLabel)
        
        let langPopup = NSPopUpButton(frame: NSRect(x: 198, y: y - 2, width: 180, height: 26))
        let languages = ["English": "en", "Auto-detect": "auto", "Hindi": "hi", "Spanish": "es", "French": "fr", "German": "de"]
        for label in languages.keys.sorted() { langPopup.addItem(withTitle: label) }
        langPopup.target = self
        langPopup.action = #selector(languageChanged(_:))
        view.addSubview(langPopup)
        
        if let currentLang = delegate?.language, let match = languages.first(where: { $1 == currentLang }) {
            langPopup.selectItem(withTitle: match.key)
        }
        
        y -= 35
        
        let modelLabel = NSTextField(labelWithString: "Local model")
        modelLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        modelLabel.frame = NSRect(x: padding, y: y, width: 120, height: 20)
        view.addSubview(modelLabel)
        
        let modelName = delegate?.modelPath != nil ? (delegate!.modelPath! as NSString).lastPathComponent : "Not installed"
        let modelVal = NSTextField(labelWithString: modelName)
        modelVal.font = NSFont.systemFont(ofSize: 14)
        modelVal.textColor = .labelColor
        modelVal.frame = NSRect(x: 200, y: y, width: 300, height: 20)
        view.addSubview(modelVal)
        
        y -= 20
        let installedIndicator = NSTextField(labelWithString: "● Installed locally")
        installedIndicator.font = NSFont.systemFont(ofSize: 12)
        installedIndicator.textColor = delegate?.modelPath != nil ? .systemGreen : .systemRed
        installedIndicator.frame = NSRect(x: 200, y: y, width: 300, height: 16)
        view.addSubview(installedIndicator)
        
        y -= 40
        
        // --- 3. TEXT INTELLIGENCE ---
        addSectionHeader(in: view, title: "TEXT INTELLIGENCE", y: y, padding: padding)
        y -= 35
        
        fillersCheck = createCheckbox(title: "Remove filler words", x: 200, y: y, width: 200, action: #selector(toggleSetting(_:)))
        view.addSubview(fillersCheck)
        
        smartCheck = createCheckbox(title: "Smart formatting", x: 420, y: y, width: 200, action: #selector(toggleSetting(_:)))
        view.addSubview(smartCheck)
        
        y -= 40
        
        // --- 4. DICTIONARY & SNIPPETS ---
        addSectionHeader(in: view, title: "DICTIONARY & SNIPPETS", y: y, padding: padding)
        y -= 25
        
        let dictHelp = NSTextField(labelWithString: "Teach Echoflow your words and reusable phrases.")
        dictHelp.font = NSFont.systemFont(ofSize: 13)
        dictHelp.textColor = .secondaryLabelColor
        dictHelp.frame = NSRect(x: padding, y: y, width: 680, height: 18)
        view.addSubview(dictHelp)
        y -= 40
        
        let editDictButton = NSButton(title: "Edit Dictionary & Snippets…", target: self, action: #selector(openDictionarySheet(_:)))
        editDictButton.frame = NSRect(x: padding, y: y, width: 220, height: 30)
        editDictButton.bezelStyle = .rounded
        view.addSubview(editDictButton)
        
        y -= 40
        addSeparator(in: view, at: y, padding: padding)
        y -= 30
        
        // Launch at login (Footer)
        launchAtLoginCheck = createCheckbox(title: "Launch at Login", x: padding, y: 20, width: 200, action: #selector(toggleLaunchAtLogin(_:)))
        launchAtLoginCheck.state = EchoflowAppService.shared.isLaunchAtLoginEnabled ? .on : .off
        view.addSubview(launchAtLoginCheck)
        
        let copyButton = NSButton(title: "Copy Last Transcript", target: self, action: #selector(copyLastTranscript(_:)))
        copyButton.frame = NSRect(x: 760 - padding - 180, y: 15, width: 180, height: 30)
        view.addSubview(copyButton)
        
        updateCheckboxStates()
    }
    
    private func addSectionHeader(in view: NSView, title: String, y: CGFloat, padding: CGFloat) {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        label.frame = NSRect(x: padding, y: y, width: 680, height: 16)
        view.addSubview(label)
    }
    
    private func addSeparator(in view: NSView, at y: CGFloat, padding: CGFloat) {
        let sep = NSBox(frame: NSRect(x: padding, y: y, width: 760 - (padding * 2), height: 1))
        sep.boxType = .separator
        view.addSubview(sep)
    }
    
    private func createCheckbox(title: String, x: CGFloat, y: CGFloat, width: CGFloat, action: Selector) -> NSButton {
        let btn = NSButton(checkboxWithTitle: title, target: self, action: action)
        btn.frame = NSRect(x: x, y: y, width: width, height: 22)
        btn.font = NSFont.systemFont(ofSize: 14)
        return btn
    }
    
    func updateCheckboxStates() {
        guard let delegate = delegate else { return }
        fillersCheck.state = delegate.removeFillers ? .on : .off
        smartCheck.state = delegate.smartFormatting ? .on : .off
        pasteCheck.state = delegate.autoPaste ? .on : .off
        audioCheck.state = delegate.retainAudio ? .on : .off
    }
    
    @objc private func toggleSetting(_ sender: NSButton) {
        let isOn = sender.state == .on
        if sender == fillersCheck { delegate?.removeFillers = isOn }
        else if sender == smartCheck { delegate?.smartFormatting = isOn }
        else if sender == pasteCheck { delegate?.autoPaste = isOn }
        else if sender == audioCheck { delegate?.retainAudio = isOn }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        EchoflowAppService.shared.setLaunchAtLogin(enabled: sender.state == .on)
    }
    
    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let languages = ["English": "en", "Auto-detect": "auto", "Hindi": "hi", "Spanish": "es", "French": "fr", "German": "de"]
        if let title = sender.titleOfSelectedItem, let code = languages[title] {
            delegate?.language = code
        }
    }
    
    @objc private func copyLastTranscript(_ sender: Any) {
        delegate?.copyLastTranscript(sender)
    }
    
    @objc private func openDictionarySheet(_ sender: Any) {
        guard let window = self.window, let sheet = dictionarySheetController.window else { return }
        dictionarySheetController.refreshJSONEditor()
        window.beginSheet(sheet)
    }
}
