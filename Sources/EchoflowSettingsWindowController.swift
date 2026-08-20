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
    
    private var modelPopup: NSPopUpButton!
    private var modelActionButton: NSButton!
    private var modelStatusLabel: NSTextField!
    private var modelProgress: NSProgressIndicator!
    private var modelRefreshTimer: Timer?
    
    private var dictionarySheetController: EchoflowDictionarySheetController!
    private var historySheetController: EchoflowHistorySheetController!
    
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
        historySheetController = EchoflowHistorySheetController(delegate: delegate)
        
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
        
        let dictationPopup = NSPopUpButton(frame: NSRect(x: 198, y: y - 2, width: 140, height: 26))
        let dOptions = [
            "Hold Fn": "fn",
            "Hold Option": "opt",
            "Hold Control": "ctrl",
            "Hold Command": "cmd"
        ]
        // Sort keys logically
        let dKeys = ["Hold Fn", "Hold Option", "Hold Control", "Hold Command"]
        for key in dKeys { dictationPopup.addItem(withTitle: key) }
        dictationPopup.target = self
        dictationPopup.action = #selector(dictationHotkeyChanged(_:))
        view.addSubview(dictationPopup)
        
        if let currentDH = delegate?.dictationHotkey, let match = dOptions.first(where: { $1 == currentDH }) {
            dictationPopup.selectItem(withTitle: match.key)
        }
        
        y -= 35
        
        let undoLabel = NSTextField(labelWithString: "Undo shortcut")
        undoLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        undoLabel.frame = NSRect(x: padding, y: y, width: 120, height: 20)
        view.addSubview(undoLabel)
        
        let undoPopup = NSPopUpButton(frame: NSRect(x: 198, y: y - 2, width: 140, height: 26))
        let uOptions = [
            "Option + Z": "opt_z",
            "Command + U": "cmd_u",
            "Control + Z": "ctrl_z"
        ]
        let uKeys = ["Option + Z", "Command + U", "Control + Z"]
        for key in uKeys { undoPopup.addItem(withTitle: key) }
        undoPopup.target = self
        undoPopup.action = #selector(undoHotkeyChanged(_:))
        view.addSubview(undoPopup)
        
        if let currentUH = delegate?.undoHotkey, let match = uOptions.first(where: { $1 == currentUH }) {
            undoPopup.selectItem(withTitle: match.key)
        }
        
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
        
        modelPopup = NSPopUpButton(frame: NSRect(x: 198, y: y - 2, width: 220, height: 26))
        modelPopup.addItem(withTitle: EchoflowModelManager.ModelType.base.displayName)
        modelPopup.addItem(withTitle: EchoflowModelManager.ModelType.small.displayName)
        modelPopup.target = self
        modelPopup.action = #selector(modelSelectionChanged(_:))
        view.addSubview(modelPopup)
        
        // Select active model in dropdown
        let currentActiveRaw = delegate?.activeModel ?? EchoflowModelManager.ModelType.base.rawValue
        if currentActiveRaw == EchoflowModelManager.ModelType.base.rawValue {
            modelPopup.selectItem(at: 0)
        } else {
            modelPopup.selectItem(at: 1)
        }
        
        modelActionButton = NSButton(title: "Download", target: self, action: #selector(modelActionClicked(_:)))
        modelActionButton.frame = NSRect(x: 430, y: y - 2, width: 100, height: 24)
        modelActionButton.bezelStyle = .rounded
        view.addSubview(modelActionButton)
        
        y -= 25
        modelStatusLabel = NSTextField(labelWithString: "Checking status...")
        modelStatusLabel.font = NSFont.systemFont(ofSize: 12)
        modelStatusLabel.textColor = .secondaryLabelColor
        modelStatusLabel.frame = NSRect(x: 200, y: y, width: 220, height: 16)
        view.addSubview(modelStatusLabel)
        
        modelProgress = NSProgressIndicator(frame: NSRect(x: 430, y: y, width: 100, height: 16))
        modelProgress.style = .bar
        modelProgress.isIndeterminate = false
        modelProgress.minValue = 0.0
        modelProgress.maxValue = 1.0
        modelProgress.doubleValue = 0.0
        modelProgress.isHidden = true
        view.addSubview(modelProgress)
        
        updateModelUI()
        
        modelRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            if EchoflowModelManager.shared.isDownloading() { return }
            self?.updateModelUI()
        })
        
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
        
        let historyButton = NSButton(title: "View Transcription History…", target: self, action: #selector(openHistorySheet(_:)))
        historyButton.frame = NSRect(x: 260, y: y, width: 220, height: 30)
        historyButton.bezelStyle = .rounded
        view.addSubview(historyButton)
        
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
    
    @objc private func dictationHotkeyChanged(_ sender: NSPopUpButton) {
        let options = [
            "Hold Fn": "fn",
            "Hold Option": "opt",
            "Hold Control": "ctrl",
            "Hold Command": "cmd"
        ]
        if let title = sender.titleOfSelectedItem, let code = options[title] {
            delegate?.dictationHotkey = code
        }
    }
    
    @objc private func undoHotkeyChanged(_ sender: NSPopUpButton) {
        let options = [
            "Option + Z": "opt_z",
            "Command + U": "cmd_u",
            "Control + Z": "ctrl_z"
        ]
        if let title = sender.titleOfSelectedItem, let code = options[title] {
            delegate?.undoHotkey = code
        }
    }
    
    @objc private func modelSelectionChanged(_ sender: NSPopUpButton) {
        updateModelUI()
    }
    
    @objc private func modelActionClicked(_ sender: NSButton) {
        let isBaseSelected = modelPopup.indexOfSelectedItem == 0
        let type: EchoflowModelManager.ModelType = isBaseSelected ? .base : .small
        
        if EchoflowModelManager.shared.isDownloading() {
            EchoflowModelManager.shared.cancelDownload()
            updateModelUI()
            return
        }
        
        let path = EchoflowModelManager.shared.getModelPath(type)
        if path != nil {
            // It's installed, but not active. Set active!
            delegate?.activeModel = type.rawValue
            updateModelUI()
            return
        }
        
        // Start download
        modelActionButton.title = "Cancel"
        modelStatusLabel.stringValue = "Downloading..."
        modelStatusLabel.textColor = .systemOrange
        modelProgress.isHidden = false
        modelProgress.doubleValue = 0.0
        
        EchoflowModelManager.shared.downloadModel(type) { [weak self] progress in
            self?.modelProgress.doubleValue = progress
        } completion: { [weak self] result in
            switch result {
            case .success(_):
                self?.delegate?.activeModel = type.rawValue // Auto-activate on download finish
                self?.updateModelUI()
            case .failure(let error):
                if (error as NSError).code == NSURLErrorCancelled {
                    self?.updateModelUI()
                } else {
                    self?.modelStatusLabel.stringValue = "Download Failed: \(error.localizedDescription)"
                    self?.modelStatusLabel.textColor = .systemRed
                    self?.modelActionButton.title = "Retry"
                    self?.modelProgress.isHidden = true
                }
            }
        }
    }
    
    private func updateModelUI() {
        if EchoflowModelManager.shared.isDownloading() { return }
        
        let isBaseSelected = modelPopup.indexOfSelectedItem == 0
        let type: EchoflowModelManager.ModelType = isBaseSelected ? .base : .small
        let path = EchoflowModelManager.shared.getModelPath(type)
        
        if path != nil {
            let currentActiveRaw = delegate?.activeModel ?? EchoflowModelManager.ModelType.base.rawValue
            if currentActiveRaw == type.rawValue {
                modelActionButton.title = "Active"
                modelActionButton.isEnabled = false
                modelStatusLabel.stringValue = "● Installed and Active"
                modelStatusLabel.textColor = .systemGreen
            } else {
                modelActionButton.title = "Set Active"
                modelActionButton.isEnabled = true
                modelStatusLabel.stringValue = "● Installed (Inactive)"
                modelStatusLabel.textColor = .secondaryLabelColor
            }
            modelProgress.isHidden = true
        } else {
            modelActionButton.title = "Download"
            modelActionButton.isEnabled = true
            modelStatusLabel.stringValue = "○ Not installed"
            modelStatusLabel.textColor = .secondaryLabelColor
            modelProgress.isHidden = true
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
    
    @objc private func openHistorySheet(_ sender: Any) {
        guard let window = self.window, let sheet = historySheetController.window else { return }
        historySheetController.refreshList()
        window.beginSheet(sheet)
    }
}
