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
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 30
        mainStack.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // --- HEADER ---
        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 16
        
        let headerLabel = NSTextField(labelWithString: "Echoflow")
        headerLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        headerRow.addArrangedSubview(headerLabel)
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        statusIndicator = NSTextField(labelWithString: "Ready")
        statusIndicator.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        statusIndicator.textColor = .secondaryLabelColor
        headerRow.addArrangedSubview(statusIndicator)
        
        statusDot = NSTextField(labelWithString: "●")
        statusDot.font = NSFont.systemFont(ofSize: 18)
        statusDot.textColor = .systemGreen
        headerRow.addArrangedSubview(statusDot)
        
        mainStack.addArrangedSubview(headerRow)
        headerRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -80).isActive = true
        
        let instruction = NSTextField(labelWithString: "Speak naturally. Your audio stays on this Mac.")
        instruction.font = NSFont.systemFont(ofSize: 14)
        instruction.textColor = .secondaryLabelColor
        mainStack.addArrangedSubview(instruction)
        mainStack.setCustomSpacing(15, after: headerRow)
        
        addSeparator(to: mainStack)
        
        // --- 1. DICTATION ---
        addSectionHeader(to: mainStack, title: "DICTATION")
        
        let dictationGrid = NSGridView(views: [
            [createLabel("Hold shortcut:"), createDictationPopup()],
            [createLabel("Undo shortcut:"), createUndoPopup()]
        ])
        dictationGrid.rowSpacing = 16
        dictationGrid.columnSpacing = 16
        dictationGrid.rowAlignment = .firstBaseline
        mainStack.addArrangedSubview(dictationGrid)
        
        let dictationChecks = NSStackView()
        dictationChecks.orientation = .vertical
        dictationChecks.alignment = .leading
        dictationChecks.spacing = 10
        
        pasteCheck = createCheckbox(title: "Paste into the active app", action: #selector(toggleSetting(_:)))
        dictationChecks.addArrangedSubview(pasteCheck)
        
        audioCheck = createCheckbox(title: "Keep source audio", action: #selector(toggleSetting(_:)))
        dictationChecks.addArrangedSubview(audioCheck)
        mainStack.addArrangedSubview(dictationChecks)
        
        addSeparator(to: mainStack)
        
        // --- 2. LANGUAGE & MODEL ---
        addSectionHeader(to: mainStack, title: "LANGUAGE & MODEL")
        
        let langPopup = NSPopUpButton()
        let languages = ["English": "en", "Auto-detect": "auto", "Hindi": "hi", "Spanish": "es", "French": "fr", "German": "de"]
        for label in languages.keys.sorted() { langPopup.addItem(withTitle: label) }
        langPopup.target = self
        langPopup.action = #selector(languageChanged(_:))
        if let currentLang = delegate?.language, let match = languages.first(where: { $1 == currentLang }) {
            langPopup.selectItem(withTitle: match.key)
        }
        
        modelPopup = NSPopUpButton()
        modelPopup.addItem(withTitle: EchoflowModelManager.ModelType.base.displayName)
        modelPopup.addItem(withTitle: EchoflowModelManager.ModelType.small.displayName)
        modelPopup.target = self
        modelPopup.action = #selector(modelSelectionChanged(_:))
        
        let currentActiveRaw = delegate?.activeModel ?? EchoflowModelManager.ModelType.base.rawValue
        if currentActiveRaw == EchoflowModelManager.ModelType.base.rawValue {
            modelPopup.selectItem(at: 0)
        } else {
            modelPopup.selectItem(at: 1)
        }
        
        let modelActionStack = NSStackView()
        modelActionStack.orientation = .horizontal
        modelActionStack.spacing = 10
        modelActionStack.addArrangedSubview(modelPopup)
        
        modelActionButton = NSButton(title: "Download", target: self, action: #selector(modelActionClicked(_:)))
        modelActionButton.bezelStyle = .rounded
        modelActionStack.addArrangedSubview(modelActionButton)
        
        modelStatusLabel = NSTextField(labelWithString: "Checking status...")
        modelStatusLabel.font = NSFont.systemFont(ofSize: 12)
        modelStatusLabel.textColor = .secondaryLabelColor
        modelActionStack.addArrangedSubview(modelStatusLabel)
        
        modelProgress = NSProgressIndicator()
        modelProgress.style = .bar
        modelProgress.isIndeterminate = false
        modelProgress.minValue = 0.0
        modelProgress.maxValue = 1.0
        modelProgress.doubleValue = 0.0
        modelProgress.isHidden = true
        modelProgress.widthAnchor.constraint(equalToConstant: 100).isActive = true
        modelActionStack.addArrangedSubview(modelProgress)
        
        let lmGrid = NSGridView(views: [
            [createLabel("Language:"), langPopup],
            [createLabel("Local model:"), modelActionStack]
        ])
        lmGrid.rowSpacing = 16
        lmGrid.columnSpacing = 16
        lmGrid.rowAlignment = .firstBaseline
        mainStack.addArrangedSubview(lmGrid)
        
        updateModelUI()
        modelRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            if EchoflowModelManager.shared.isDownloading() { return }
            self?.updateModelUI()
        })
        
        addSeparator(to: mainStack)
        
        // --- 3. TEXT INTELLIGENCE ---
        addSectionHeader(to: mainStack, title: "TEXT INTELLIGENCE")
        
        let textChecks = NSStackView()
        textChecks.orientation = .horizontal
        textChecks.spacing = 60
        fillersCheck = createCheckbox(title: "Remove filler words", action: #selector(toggleSetting(_:)))
        textChecks.addArrangedSubview(fillersCheck)
        smartCheck = createCheckbox(title: "Smart formatting", action: #selector(toggleSetting(_:)))
        textChecks.addArrangedSubview(smartCheck)
        mainStack.addArrangedSubview(textChecks)
        
        addSeparator(to: mainStack)
        
        // --- 4. DICTIONARY & SNIPPETS ---
        let dictRow = NSStackView()
        dictRow.orientation = .horizontal
        dictRow.alignment = .top
        dictRow.spacing = 20
        
        let dictCol = NSStackView()
        dictCol.orientation = .vertical
        dictCol.alignment = .leading
        dictCol.spacing = 10
        addSectionHeader(to: dictCol, title: "DICTIONARY & SNIPPETS")
        let dictHelp = NSTextField(labelWithString: "Teach Echoflow your words and reusable phrases.")
        dictHelp.font = NSFont.systemFont(ofSize: 13)
        dictHelp.textColor = .secondaryLabelColor
        dictCol.addArrangedSubview(dictHelp)
        
        let dictBtns = NSStackView()
        dictBtns.orientation = .horizontal
        dictBtns.spacing = 10
        let editDictButton = NSButton(title: "Edit Dictionary & Snippets…", target: self, action: #selector(openDictionarySheet(_:)))
        editDictButton.bezelStyle = .rounded
        dictBtns.addArrangedSubview(editDictButton)
        let historyButton = NSButton(title: "View Transcription History…", target: self, action: #selector(openHistorySheet(_:)))
        historyButton.bezelStyle = .rounded
        dictBtns.addArrangedSubview(historyButton)
        dictCol.addArrangedSubview(dictBtns)
        
        dictRow.addArrangedSubview(dictCol)
        mainStack.addArrangedSubview(dictRow)
        
        addSeparator(to: mainStack)
        
        // --- FOOTER ---
        let footerRow = NSStackView()
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        
        launchAtLoginCheck = createCheckbox(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)))
        launchAtLoginCheck.state = EchoflowAppService.shared.isLaunchAtLoginEnabled ? .on : .off
        footerRow.addArrangedSubview(launchAtLoginCheck)
        
        let fSpacer = NSView()
        fSpacer.translatesAutoresizingMaskIntoConstraints = false
        footerRow.addArrangedSubview(fSpacer)
        fSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let copyButton = NSButton(title: "Copy Last Transcript", target: self, action: #selector(copyLastTranscript(_:)))
        copyButton.bezelStyle = .rounded
        footerRow.addArrangedSubview(copyButton)
        
        mainStack.addArrangedSubview(footerRow)
        footerRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -80).isActive = true
        
        updateCheckboxStates()
    }
    
    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        return label
    }
    
    private func createDictationPopup() -> NSPopUpButton {
        let p = NSPopUpButton()
        let dKeys = ["Hold Fn", "Hold Option", "Hold Control", "Hold Command"]
        let dOptions = ["Hold Fn": "fn", "Hold Option": "opt", "Hold Control": "ctrl", "Hold Command": "cmd"]
        for key in dKeys { p.addItem(withTitle: key) }
        p.target = self
        p.action = #selector(dictationHotkeyChanged(_:))
        if let currentDH = delegate?.dictationHotkey, let match = dOptions.first(where: { $1 == currentDH }) {
            p.selectItem(withTitle: match.key)
        }
        return p
    }
    
    private func createUndoPopup() -> NSPopUpButton {
        let p = NSPopUpButton()
        let uKeys = ["Option + Z", "Command + U", "Control + Z"]
        let uOptions = ["Option + Z": "opt_z", "Command + U": "cmd_u", "Control + Z": "ctrl_z"]
        for key in uKeys { p.addItem(withTitle: key) }
        p.target = self
        p.action = #selector(undoHotkeyChanged(_:))
        if let currentUH = delegate?.undoHotkey, let match = uOptions.first(where: { $1 == currentUH }) {
            p.selectItem(withTitle: match.key)
        }
        return p
    }
    
    private func addSectionHeader(to stack: NSStackView, title: String) {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        stack.addArrangedSubview(label)
    }
    
    private func addSeparator(to stack: NSStackView) {
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -80).isActive = true
    }
    
    private func createCheckbox(title: String, action: Selector) -> NSButton {
        let btn = NSButton(checkboxWithTitle: title, target: self, action: action)
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
