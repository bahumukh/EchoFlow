import Cocoa
import AVFoundation

class EchoflowOnboardingController: NSWindowController {
    
    private var micStatusLabel: NSTextField!
    private var micButton: NSButton!
    private var axStatusLabel: NSTextField!
    private var axButton: NSButton!
    private var continueButton: NSButton!
    
    weak var delegate: EchoflowAppDelegate?
    private var permissionTimer: Timer?
    
    convenience init(delegate: EchoflowAppDelegate) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        self.delegate = delegate
        
        window.title = "Welcome to Echoflow"
        window.center()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        
        let effectView = NSVisualEffectView(frame: window.contentView!.bounds)
        effectView.material = .underWindowBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        window.contentView = effectView
        
        buildUI(in: effectView)
        startPermissionWatcher()
    }
    
    private func buildUI(in view: NSView) {
        var y: CGFloat = 320
        
        let titleLabel = NSTextField(labelWithString: "Welcome to Echoflow")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: y, width: 460, height: 30)
        view.addSubview(titleLabel)
        
        y -= 25
        let subtitle = NSTextField(labelWithString: "Echoflow needs two permissions to work effectively.")
        subtitle.font = NSFont.systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.frame = NSRect(x: 20, y: y, width: 460, height: 20)
        view.addSubview(subtitle)
        
        y -= 60
        
        // Microphone Section
        let micLabel = NSTextField(labelWithString: "1. Microphone Access")
        micLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        micLabel.frame = NSRect(x: 40, y: y, width: 420, height: 20)
        view.addSubview(micLabel)
        
        y -= 20
        let micDesc = NSTextField(labelWithString: "Required to record your voice for dictation.")
        micDesc.font = NSFont.systemFont(ofSize: 13)
        micDesc.textColor = .secondaryLabelColor
        micDesc.frame = NSRect(x: 40, y: y, width: 280, height: 20)
        view.addSubview(micDesc)
        
        micStatusLabel = NSTextField(labelWithString: "Pending")
        micStatusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        micStatusLabel.textColor = .systemOrange
        micStatusLabel.frame = NSRect(x: 340, y: y, width: 120, height: 20)
        view.addSubview(micStatusLabel)
        
        y -= 30
        micButton = NSButton(title: "Grant Microphone Access", target: self, action: #selector(requestMicrophone(_:)))
        micButton.frame = NSRect(x: 40, y: y, width: 200, height: 24)
        micButton.bezelStyle = .rounded
        view.addSubview(micButton)
        
        y -= 50
        
        // Accessibility Section
        let axLabel = NSTextField(labelWithString: "2. Accessibility Access")
        axLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        axLabel.frame = NSRect(x: 40, y: y, width: 420, height: 20)
        view.addSubview(axLabel)
        
        y -= 20
        let axDesc = NSTextField(labelWithString: "Required to paste transcribed text and detect hotkeys.")
        axDesc.font = NSFont.systemFont(ofSize: 13)
        axDesc.textColor = .secondaryLabelColor
        axDesc.frame = NSRect(x: 40, y: y, width: 330, height: 20)
        view.addSubview(axDesc)
        
        axStatusLabel = NSTextField(labelWithString: "Pending")
        axStatusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        axStatusLabel.textColor = .systemOrange
        axStatusLabel.frame = NSRect(x: 370, y: y, width: 100, height: 20)
        view.addSubview(axStatusLabel)
        
        y -= 30
        axButton = NSButton(title: "Open System Settings", target: self, action: #selector(requestAccessibility(_:)))
        axButton.frame = NSRect(x: 40, y: y, width: 180, height: 24)
        axButton.bezelStyle = .rounded
        view.addSubview(axButton)
        
        y -= 60
        
        continueButton = NSButton(title: "Get Started", target: self, action: #selector(finishOnboarding(_:)))
        continueButton.frame = NSRect(x: 180, y: y, width: 140, height: 32)
        continueButton.bezelStyle = .rounded
        continueButton.keyEquivalent = "\r"
        continueButton.isEnabled = false
        view.addSubview(continueButton)
        
        updateStatuses()
    }
    
    private func startPermissionWatcher() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatuses()
        }
    }
    
    private func updateStatuses() {
        // Check Mic
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let isMicGranted = (micStatus == .authorized)
        
        if isMicGranted {
            micStatusLabel.stringValue = "Granted ✅"
            micStatusLabel.textColor = .systemGreen
            micButton.isEnabled = false
        } else if micStatus == .denied || micStatus == .restricted {
            micStatusLabel.stringValue = "Denied ❌"
            micStatusLabel.textColor = .systemRed
            micButton.title = "Open System Settings"
            micButton.isEnabled = true
        }
        
        // Check Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isAxGranted = AXIsProcessTrustedWithOptions(options)
        
        if isAxGranted {
            axStatusLabel.stringValue = "Granted ✅"
            axStatusLabel.textColor = .systemGreen
            axButton.isEnabled = false
        }
        
        // Enable continue if both granted
        if isMicGranted && isAxGranted {
            continueButton.isEnabled = true
        }
    }
    
    @objc private func requestMicrophone(_ sender: NSButton) {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatuses()
                }
            }
        } else {
            // Already denied, open settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func requestAccessibility(_ sender: NSButton) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Prompt option above usually shows Apple's dialog, but often people need to open it directly:
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func finishOnboarding(_ sender: NSButton) {
        permissionTimer?.invalidate()
        self.close()
        delegate?.showSettingsWindow()
    }
    
    func windowWillClose(_ notification: Notification) {
        permissionTimer?.invalidate()
    }
}
