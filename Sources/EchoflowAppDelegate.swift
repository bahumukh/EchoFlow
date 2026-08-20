import Cocoa
import AVFoundation
import ApplicationServices
import Carbon

// MARK: - Dictation State

enum LFState {
    case idle
    case recording
    case transcribing
}

// MARK: - App Delegate

class EchoflowAppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - State

    private var state: LFState = .idle
    private var shortcutDown = false

    // MARK: - UI

    private var settingsWindowController: EchoflowSettingsWindowController!
    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!

    // MARK: - Audio

    private var recorder: EchoflowAudioRecorder!
    private var currentAudioURL: URL?
    private var capturedAppBundleID = ""
    private var capturedAppName = "Unknown app"

    // MARK: - Settings
    
    var settings: [String: Any] = [:]
    var history: [[String: Any]] = []
    private var lastTranscript: String?

    // MARK: - Permissions
    private var permissionTimer: Timer?
    private var accessibilityGranted = false

    // MARK: - Paths

    private var appSupportDir: URL!
    private var recordingsDir: URL!
    private var settingsFileURL: URL!
    private var historyFileURL: URL!

    // MARK: - Runtime

    private var whisperCLIPath: String?
    var modelPath: String?

    // MARK: - Default Settings

    private static let defaultSettings: [String: Any] = [
        "language": "en",
        "removeFillers": true,
        "smartFormatting": true,
        "autoPaste": true,
        "retainAudio": false,
        "dictionary": [
            ["spoken": "whisper flow", "replacement": "Echoflow", "priority": false],
            ["spoken": "API", "replacement": "API", "priority": true]
        ],
        "snippets": [
            ["trigger": "my email", "expansion": "your.email@example.com"],
            ["trigger": "organize my thoughts", "expansion": "Please organize the following thoughts into a concise, structured response:"]
        ]
    ]

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // FR-INIT-001: Regular activation policy
        NSApp.setActivationPolicy(.regular)

        // FR-INIT-003: Prepare storage
        setupStorage()

        // FR-INIT-003: Load settings and history
        loadSettings()
        loadHistory()

        // FR-INIT-004: Initialize recorder
        recorder = EchoflowAudioRecorder()
        recorder.levelHandler = { level in
            DispatchQueue.main.async {
                EchoflowHUDController.shared.waveformView.addLevel(CGFloat(level))
            }
        }

        // Discover runtime
        discoverRuntime()

        // FR-INIT-005: Build UI
        settingsWindowController = EchoflowSettingsWindowController(delegate: self)
        buildMenuBar()

        // FR-INIT-006: Check/prompt Accessibility
        checkAccessibility(prompt: true)
        startPermissionWatcher()

        // FR-INIT-007: Show settings window
        showSettingsWindow()

        // FR-INIT-008: Surface missing runtime
        if whisperCLIPath == nil || modelPath == nil {
            EchoflowHUDController.shared.show(state: .error("Echoflow needs its local speech engine before it can transcribe."), hideAfter: 4.0)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }
    
    func showSettingsWindow() {
        settingsWindowController.updateCheckboxStates()
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop recorder if active
        if recorder.isRecording {
            recorder.stop()
        }

        // Invalidate permission timer
        permissionTimer?.invalidate()
        permissionTimer = nil

        // Remove hotkey
        removeGlobalHotkey()
    }

    // MARK: - Storage Setup

    private func setupStorage() {
        let fm = FileManager.default
        appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Echoflow")
        recordingsDir = appSupportDir.appendingPathComponent("Recordings")

        try? fm.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        settingsFileURL = appSupportDir.appendingPathComponent("settings.json")
        historyFileURL = appSupportDir.appendingPathComponent("history.json")
    }

    // MARK: - Settings

    private func loadSettings() {
        // Start with defaults
        settings = EchoflowAppDelegate.defaultSettings

        // Try to load saved settings and merge
        if let data = try? Data(contentsOf: settingsFileURL),
           let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in saved {
                settings[key] = value
            }
        }

        // Save merged settings immediately
        saveSettings()
    }

    func saveSettings() {
        if let data = try? JSONSerialization.data(withJSONObject: settings,
                                                   options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsFileURL, options: .atomic)
        }
    }

    // Settings accessors
    var language: String {
        get { settings["language"] as? String ?? "en" }
        set { settings["language"] = newValue; saveSettings() }
    }
    var removeFillers: Bool {
        get { settings["removeFillers"] as? Bool ?? true }
        set { settings["removeFillers"] = newValue; saveSettings() }
    }
    var smartFormatting: Bool {
        get { settings["smartFormatting"] as? Bool ?? true }
        set { settings["smartFormatting"] = newValue; saveSettings() }
    }
    var autoPaste: Bool {
        get { settings["autoPaste"] as? Bool ?? true }
        set { settings["autoPaste"] = newValue; saveSettings() }
    }
    var retainAudio: Bool {
        get { settings["retainAudio"] as? Bool ?? false }
        set { settings["retainAudio"] = newValue; saveSettings() }
    }
    var dictionaryEntries: [[String: Any]] {
        get { settings["dictionary"] as? [[String: Any]] ?? [] }
    }
    var snippetEntries: [[String: Any]] {
        get { settings["snippets"] as? [[String: Any]] ?? [] }
    }

    // MARK: - History

    private func loadHistory() {
        if let data = try? Data(contentsOf: historyFileURL),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            history = array
        } else {
            history = []
        }
    }

    private func addHistoryEntry(_ entry: [String: Any]) {
        history.insert(entry, at: 0)
        // Cap at 500
        if history.count > 500 {
            history = Array(history.prefix(500))
        }
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONSerialization.data(withJSONObject: history,
                                                   options: [.prettyPrinted]) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }

    // MARK: - Runtime Discovery (Section 9.7)

    private func discoverRuntime() {
        let modelPriority = [
            "ggml-small.en.bin",
            "ggml-base.en.bin",
            "ggml-small.bin",
            "ggml-base.bin"
        ]

        // Search roots in order
        var roots: [String] = []

        // 1. Bundle resources/Runtime
        if let bundlePath = Bundle.main.resourcePath {
            roots.append(bundlePath + "/Runtime")
        }

        // 2. CWD/Runtime
        roots.append(FileManager.default.currentDirectoryPath + "/Runtime")

        // 3. Source root (walk up from executable)
        if let execPath = Bundle.main.executablePath {
            var dir = (execPath as NSString).deletingLastPathComponent
            for _ in 0..<5 {
                let candidate = dir + "/Runtime"
                if FileManager.default.fileExists(atPath: candidate + "/whisper-cli") {
                    roots.append(candidate)
                    break
                }
                dir = (dir as NSString).deletingLastPathComponent
            }
        }

        let fm = FileManager.default
        for root in roots {
            let cliPath = root + "/whisper-cli"
            guard fm.isExecutableFile(atPath: cliPath) else { continue }

            // Find first available model
            for model in modelPriority {
                let mPath = root + "/models/" + model
                if fm.fileExists(atPath: mPath) {
                    whisperCLIPath = cliPath
                    modelPath = mPath
                    return
                }
            }
        }
    }

    // Settings UI is now handled by EchoflowSettingsWindowController

    // MARK: - Transcript actions
    
    @objc func copyLastTranscript(_ sender: Any) {
        var text: String?

        // Use in-memory latest transcript if present
        if let last = lastTranscript {
            text = last
        } else if let first = history.first, let finalText = first["finalText"] as? String {
            text = finalText
        }

        if let text = text, !text.isEmpty {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }
    }

    // MARK: - Menu Bar (Section 8.5)

    private var statusTitleItem: NSMenuItem!
    private var infoItem: NSMenuItem!

    private func buildMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // "monochrome template form"
            let icon = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Echoflow")
            icon?.isTemplate = true
            button.image = icon
        }

        let menu = NSMenu()

        // 1. Status Title (e.g. ● Ready)
        statusTitleItem = NSMenuItem(title: "● Ready", action: nil, keyEquivalent: "")
        statusTitleItem.isEnabled = false
        menu.addItem(statusTitleItem)

        // 2. Info row
        infoItem = NSMenuItem(title: "Hold Fn to dictate", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Toggle item
        toggleMenuItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation(_:)), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        // 4. Copy Last
        let copyItem = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyLastTranscript(_:)), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Open Echoflow
        let openItem = NSMenuItem(title: "Open Echoflow…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)

        // 6. Refresh Permissions
        let refreshItem = NSMenuItem(title: "Refresh Permissions", action: #selector(refreshPermissions(_:)), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        // 7. Quit
        let quitItem = NSMenuItem(title: "Quit Echoflow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateMenuState() {
        switch state {
        case .idle:
            statusTitleItem.title = "● Ready"
            infoItem.title = "Hold Fn to dictate"
            toggleMenuItem.title = "Start Dictation"
            toggleMenuItem.isEnabled = true
            statusItem.button?.contentTintColor = nil
        case .recording:
            statusTitleItem.title = "🔴 Recording"
            infoItem.title = "Hold Fn to dictate"
            toggleMenuItem.title = "Stop Dictation"
            toggleMenuItem.isEnabled = true
            statusItem.button?.contentTintColor = .systemRed
        case .transcribing:
            statusTitleItem.title = "◌ Transcribing locally…"
            infoItem.title = "Audio never leaves this Mac"
            toggleMenuItem.title = "Transcribing…"
            toggleMenuItem.isEnabled = false
            statusItem.button?.contentTintColor = .systemOrange
        }
    }

    @objc private func toggleDictation(_ sender: Any) {
        switch state {
        case .idle:
            startDictation()
        case .recording:
            stopDictation()
        default:
            break
        }
    }

    @objc private func openSettings(_ sender: Any) {
        showSettingsWindow()
    }

    @objc private func refreshPermissions(_ sender: Any) {
        checkAccessibility(prompt: true)
    }

    // HUD UI is now handled by EchoflowHUDController

    // MARK: - Permissions (Section 8.2)

    private func checkAccessibility(prompt: Bool = false) {
        let trusted: Bool
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            trusted = AXIsProcessTrustedWithOptions(options)
        } else {
            trusted = AXIsProcessTrusted()
        }

        if trusted && !accessibilityGranted {
            // Permission newly granted
            accessibilityGranted = true
            installGlobalHotkey()
            EchoflowHUDController.shared.show(state: .info("Echoflow is ready", "Hold Fn to dictate"), hideAfter: 2.5)
        } else if trusted {
            accessibilityGranted = true
            if globalMonitor == nil {
                installGlobalHotkey()
            }
        } else if !trusted && accessibilityGranted {
            // Permission revoked
            accessibilityGranted = false
            removeGlobalHotkey()
        } else {
            accessibilityGranted = false
        }
    }

    private func startPermissionWatcher() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkAccessibility()
        }
    }
    // MARK: - Global Shortcut (Fn Key) (Section 8.4)

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private func installGlobalHotkey() {
        guard globalMonitor == nil else { return }

        let handler: (NSEvent) -> Void = { [weak self] event in
            // .function modifier corresponds to the Fn / Globe key
            let isFnDown = event.modifierFlags.contains(.function)

            if isFnDown {
                if self?.shortcutDown == false {
                    self?.shortcutDown = true
                    DispatchQueue.main.async {
                        self?.startDictation()
                    }
                }
            } else {
                if self?.shortcutDown == true {
                    self?.shortcutDown = false
                    DispatchQueue.main.async {
                        self?.stopDictation()
                    }
                }
            }
        }

        // Listen for modifier flag changes globally
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler)
        
        // Also listen locally (in case our own settings window is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        }
    }

    private func removeGlobalHotkey() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
        shortcutDown = false
    }

    // MARK: - Dictation Flow (Section 8.3)

    func startDictation() {
        // FR-STATE-001: Ignore unless idle
        guard state == .idle else { return }

        // Verify runtime
        guard let _ = whisperCLIPath, let _ = modelPath else {
            EchoflowHUDController.shared.show(state: .error("Echoflow needs its local speech engine before it can transcribe."), hideAfter: 4.0)
            return
        }

        // FR-CTX-001: Capture frontmost app context
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            capturedAppBundleID = frontApp.bundleIdentifier ?? ""
            capturedAppName = frontApp.localizedName ?? "Unknown app"
        } else {
            capturedAppBundleID = ""
            capturedAppName = "Unknown app"
        }

        // FR-MIC-001: Check microphone authorization
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecording()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.beginRecording()
                    } else {
                        EchoflowHUDController.shared.show(state: .error("Enable Echoflow in Privacy & Security → Microphone."), hideAfter: 5.0)
                    }
                }
            }
        case .denied, .restricted:
            EchoflowHUDController.shared.show(state: .error("Enable Echoflow in Privacy & Security → Microphone."), hideAfter: 5.0)
        @unknown default:
            break
        }
    }

    private func beginRecording() {
        guard state == .idle else { return }

        let filename = "dictation-\(UUID().uuidString).wav"
        let fileURL = recordingsDir.appendingPathComponent(filename)
        currentAudioURL = fileURL

        do {
            EchoflowHUDController.shared.waveformView.resetSamples()
            try recorder.start(at: fileURL)
            state = .recording
            updateMenuState()

            EchoflowHUDController.shared.show(state: .listening)
        } catch {
            EchoflowHUDController.shared.show(state: .error(error.localizedDescription), hideAfter: 5.0)
            state = .idle
        }
    }

    func stopDictation() {
        // FR-STATE-002: Ignore unless recording with audio URL
        guard state == .recording, let audioURL = currentAudioURL else { return }

        let duration = recorder.stop() ?? 0

        // FR-AUDIO-010: Sub-250ms recording — delete and ignore
        if duration < 0.25 {
            try? FileManager.default.removeItem(at: audioURL)
            resetToIdle()
            EchoflowHUDController.shared.hide()
            return
        }

        state = .transcribing
        updateMenuState()

        EchoflowHUDController.shared.show(state: .transcribing)

        // Capture settings at stop time
        let capturedSettings = makeProcessingSettings()
        let capturedBundleID = capturedAppBundleID
        let capturedName = capturedAppName
        let audioRetain = retainAudio
        let shouldAutoPaste = autoPaste

        // Run Whisper on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.runWhisper(audioURL: audioURL)

            DispatchQueue.main.async {
                switch result {
                case .success(let rawText):
                    self.processAndInsert(rawText: rawText,
                                          audioURL: audioURL,
                                          settings: capturedSettings,
                                          appBundleID: capturedBundleID,
                                          appName: capturedName,
                                          duration: duration,
                                          retainAudio: audioRetain,
                                          autoPaste: shouldAutoPaste)
                case .failure(let error):
                    self.handleTranscriptionError(error, audioURL: audioURL,
                                                   appName: capturedName, duration: duration)
                }
            }
        }
    }

    // MARK: - Whisper Invocation (Section 9.8)

    private func runWhisper(audioURL: URL) -> Result<String, Error> {
        guard let cliPath = whisperCLIPath, let mPath = modelPath else {
            return .failure(NSError(domain: "Echoflow", code: 20,
                                    userInfo: [NSLocalizedDescriptionKey: "Whisper executable or model missing"]))
        }

        // Create output prefix by replacing .wav with .transcript
        let audioPath = audioURL.path
        let outputPrefix: String
        if audioPath.hasSuffix(".wav") {
            outputPrefix = String(audioPath.dropLast(4)) + ".transcript"
        } else {
            outputPrefix = audioPath + ".transcript"
        }

        let expectedOutputFile = outputPrefix + ".txt"

        // Delete stale output
        try? FileManager.default.removeItem(atPath: expectedOutputFile)

        // Build arguments
        var args = [
            "-ng",
            "-m", mPath,
            "-f", audioPath,
            "-otxt",
            "-of", outputPrefix,
            "-nt",
            "-np",
            "-sns"
        ]

        // Language
        let lang = settings["language"] as? String ?? "en"
        if lang != "auto" {
            args.append(contentsOf: ["-l", lang])
        }

        // Prompt
        let promptTerms = buildPromptTerms()
        if !promptTerms.isEmpty {
            args.append(contentsOf: ["--prompt", promptTerms])
        }

        // Launch process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(error)
        }

        guard process.terminationStatus == 0 else {
            return .failure(NSError(domain: "Echoflow", code: 21,
                                    userInfo: [NSLocalizedDescriptionKey: "whisper.cpp could not transcribe this recording."]))
        }

        // Read transcript
        guard let transcriptData = FileManager.default.contents(atPath: expectedOutputFile),
              let transcript = String(data: transcriptData, encoding: .utf8) else {
            return .failure(NSError(domain: "Echoflow", code: 21,
                                    userInfo: [NSLocalizedDescriptionKey: "Could not read transcript output."]))
        }

        // Delete .txt file after successful read
        try? FileManager.default.removeItem(atPath: expectedOutputFile)

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return .success(trimmed)
    }

    private func buildPromptTerms() -> String {
        var terms: [String] = ["Echoflow", "Option + Space", "Command-V"]

        // Append dictionary replacement values
        for entry in dictionaryEntries {
            if let replacement = entry["replacement"] as? String, !replacement.isEmpty {
                if !terms.contains(replacement) {
                    terms.append(replacement)
                }
            }
        }

        return terms.joined(separator: ". ")
    }

    // MARK: - Process and Insert (Sections 9.9, 9.10)

    private func processAndInsert(rawText: String, audioURL: URL,
                                   settings: EchoflowTextProcessor.ProcessingSettings,
                                   appBundleID: String, appName: String,
                                   duration: TimeInterval, retainAudio: Bool,
                                   autoPaste: Bool) {
        // Process text
        let result = EchoflowTextProcessor.processText(rawText, settings: settings, appBundleID: appBundleID)
        let processedText = result.text
        let pressEnter = result.pressEnter

        // Empty processed text
        if processedText.isEmpty {
            EchoflowHUDController.shared.show(state: .error("No speech was detected."), hideAfter: 5.0)
            resetToIdle()
            return
        }

        // FR-INSERT-001: Always write to clipboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(processedText, forType: .string)

        // Store last transcript
        lastTranscript = processedText

        // Determine insertion method
        let isAccessible = AXIsProcessTrusted()
        var inserted = false

        if autoPaste && isAccessible {
            // Try direct AX insertion
            inserted = attemptDirectInsertion(text: processedText, appBundleID: appBundleID)

            if inserted {
                // FR-INSERT-010: Direct insertion + pressEnter
                if pressEnter {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.postReturnKey()
                    }
                }
                EchoflowHUDController.shared.show(state: .success, hideAfter: 2.2)
            } else {
                // FR-INSERT-007: Command-V fallback after 60ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                    self?.postCommandV()
                    // FR-INSERT-011: pressEnter after 160ms from Command-V
                    if pressEnter {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                            self?.postReturnKey()
                        }
                    }
                }
                inserted = true
                EchoflowHUDController.shared.show(state: .success, hideAfter: 2.2)
            }
        }

        if !inserted {
            EchoflowHUDController.shared.show(state: .clipboard, hideAfter: 2.2)
        }

        // History entry
        var entry: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSince1970,
            "rawText": rawText,
            "finalText": processedText,
            "applicationName": appName,
            "duration": duration
        ]

        // Audio retention
        if retainAudio {
            entry["audioPath"] = audioURL.path
        } else {
            try? FileManager.default.removeItem(at: audioURL)
        }

        addHistoryEntry(entry)
        resetToIdle()
    }

    private func handleTranscriptionError(_ error: Error, audioURL: URL,
                                            appName: String, duration: TimeInterval) {
        EchoflowHUDController.shared.show(state: .error(error.localizedDescription), hideAfter: 5.0)

        // History entry for failed transcription
        let entry: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSince1970,
            "rawText": "",
            "finalText": "Transcription failed: \(error.localizedDescription)",
            "applicationName": appName,
            "duration": duration,
            "audioPath": audioURL.path
        ]
        addHistoryEntry(entry)
        resetToIdle()
    }

    // MARK: - Text Insertion (Section 9.10)

    private func attemptDirectInsertion(text: String, appBundleID: String) -> Bool {
        // FR-INSERT-012: Bypass direct insertion for apps known to have buggy AXSelectedText support
        // This forces the reliable Command-V fallback for browsers, terminals, and code editors.
        let lowerID = appBundleID.lowercased()
        let buggyPrefixes = [
            "com.google.chrome", "com.brave.browser", "com.microsoft.edgedev",
            "com.microsoft.vscode", "com.cursor", "com.gemini", "com.google.antigravity",
            "com.apple.terminal", "com.googlecode.iterm2", "app.warp"
        ]
        
        if buggyPrefixes.contains(where: { lowerID.hasPrefix($0) }) || lowerID.contains("antigravity") || lowerID.contains("electron") {
            return false
        }

        // FR-INSERT-004: Direct insertion through focused AX element
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard result == .success, let element = focusedElement else {
            return false
        }

        let axElement = element as! AXUIElement

        // FR-INSERT-005: Check if selectedText is settable
        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(axElement, kAXSelectedTextAttribute as CFString, &settable)

        guard settableResult == .success, settable.boolValue else {
            return false
        }

        // Set the selected text
        let setResult = AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)

        return setResult == .success
    }

    private func postCommandV() {
        // FR-INSERT-008: Command-V with key code 9 and Command flag
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) else { return }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func postReturnKey() {
        // FR-INSERT-009: Return with key code 36, no modifier
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true) else { return }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false) else { return }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Processing Settings Snapshot

    private func makeProcessingSettings() -> EchoflowTextProcessor.ProcessingSettings {
        let dict = dictionaryEntries.map { entry -> EchoflowTextProcessor.DictionaryEntry in
            EchoflowTextProcessor.DictionaryEntry(
                spoken: entry["spoken"] as? String ?? "",
                replacement: entry["replacement"] as? String ?? "",
                priority: entry["priority"] as? Bool ?? false
            )
        }

        let snips = snippetEntries.map { entry -> EchoflowTextProcessor.SnippetEntry in
            EchoflowTextProcessor.SnippetEntry(
                trigger: entry["trigger"] as? String ?? "",
                expansion: entry["expansion"] as? String ?? ""
            )
        }

        return EchoflowTextProcessor.ProcessingSettings(
            removeFillers: removeFillers,
            smartFormatting: smartFormatting,
            dictionary: dict,
            snippets: snips
        )
    }

    // MARK: - State Management

    private func resetToIdle() {
        state = .idle
        currentAudioURL = nil
        updateMenuState()
    }
}
