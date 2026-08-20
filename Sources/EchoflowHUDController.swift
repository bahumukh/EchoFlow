import Cocoa

class EchoflowHUDController {
    static let shared = EchoflowHUDController()

    private var hudPanel: NSPanel!
    private var hudTitleLabel: NSTextField!
    private var hudDetailLabel: NSTextField!
    private var hudSpinner: NSProgressIndicator!
    private var hudIconView: NSImageView!
    private(set) var waveformView: EchoflowWaveformView!
    private var hudHideTimer: Timer?
    
    // For pulsing animation
    private var isPulsing = false

    private init() {
        buildHUD()
    }

    private func buildHUD() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false

        // Inner visual effect background - Glassmorphism
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 420, height: 120))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 22
        effectView.layer?.masksToBounds = true
        
        // Add subtle glass border
        effectView.layer?.borderWidth = 1.0
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        
        panel.contentView = effectView

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 24, y: 74, width: 32, height: 32))
        iconView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Echoflow")
        iconView.contentTintColor = .systemBlue
        iconView.wantsLayer = true // Needed for animations
        effectView.addSubview(iconView)
        hudIconView = iconView

        // Title: bold 17pt
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 17)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 68, y: 81, width: 300, height: 22)
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.backgroundColor = .clear
        effectView.addSubview(titleLabel)
        hudTitleLabel = titleLabel

        // Detail: 12pt, secondary
        let detailLabel = NSTextField(labelWithString: "")
        detailLabel.font = NSFont.systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.frame = NSRect(x: 68, y: 59, width: 320, height: 18)
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.isBordered = false
        detailLabel.isEditable = false
        detailLabel.isSelectable = false
        detailLabel.backgroundColor = .clear
        effectView.addSubview(detailLabel)
        hudDetailLabel = detailLabel

        // Spinner: 18 × 18
        let spinner = NSProgressIndicator(frame: NSRect(x: 380, y: 83, width: 18, height: 18))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.isDisplayedWhenStopped = false
        effectView.addSubview(spinner)
        hudSpinner = spinner

        // Waveform: 372 × 28
        let waveform = EchoflowWaveformView(frame: NSRect(x: 24, y: 14, width: 372, height: 28))
        effectView.addSubview(waveform)
        waveformView = waveform

        hudPanel = panel
    }

    private func positionHUD() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let hudSize = hudPanel.frame.size
        let x = visibleFrame.origin.x + (visibleFrame.width - hudSize.width) / 2
        let y = visibleFrame.origin.y + 72
        hudPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    enum State {
        case listening
        case transcribing
        case success
        case clipboard
        case error(String)
        case info(String, String)
    }

    func show(state: State, hideAfter: TimeInterval? = nil) {
        hudSpinner.stopAnimation(nil)
        waveformView.isHidden = true
        stopPulseAnimation()
        hudIconView.layer?.setAffineTransform(.identity)

        switch state {
        case .listening:
            hudTitleLabel.stringValue = "Listening…"
            hudDetailLabel.stringValue = "Release ⌥ Space to transcribe and insert"
            hudIconView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
            hudIconView.contentTintColor = NSColor(calibratedRed: 0.28, green: 0.62, blue: 0.96, alpha: 1.0)
            waveformView.isHidden = false
            startPulseAnimation()

        case .transcribing:
            hudTitleLabel.stringValue = "Transcribing locally…"
            hudDetailLabel.stringValue = "Audio never leaves this Mac"
            hudIconView.image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: nil)
            hudIconView.contentTintColor = .systemIndigo
            hudSpinner.startAnimation(nil)

        case .success:
            hudTitleLabel.stringValue = "Inserted at cursor"
            hudDetailLabel.stringValue = "Processed transcript"
            hudIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            hudIconView.contentTintColor = .systemGreen
            // Success pop animation
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                hudIconView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.8, y: 0.8))
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    hudIconView.animator().layer?.setAffineTransform(.identity)
                }
            }

        case .clipboard:
            hudTitleLabel.stringValue = "Copied to clipboard"
            hudDetailLabel.stringValue = "Enable Accessibility for automatic paste"
            hudIconView.image = NSImage(systemSymbolName: "doc.on.doc.fill", accessibilityDescription: nil)
            hudIconView.contentTintColor = .systemBlue

        case .error(let msg):
            hudTitleLabel.stringValue = "Echoflow needs attention"
            hudDetailLabel.stringValue = msg
            hudIconView.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
            hudIconView.contentTintColor = .systemRed
            
        case .info(let title, let desc):
            hudTitleLabel.stringValue = title
            hudDetailLabel.stringValue = desc
            hudIconView.image = NSImage(systemSymbolName: "info.circle.fill", accessibilityDescription: nil)
            hudIconView.contentTintColor = .secondaryLabelColor
        }

        positionHUD()
        
        // Smooth slide up & fade in
        if !hudPanel.isVisible {
            hudPanel.alphaValue = 0.0
            hudPanel.orderFront(nil)
            
            var frame = hudPanel.frame
            let motionEnabled = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            if motionEnabled {
                frame.origin.y -= 10
                hudPanel.setFrame(frame, display: false)
                frame.origin.y += 10
            }
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = motionEnabled ? 0.2 : 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                hudPanel.animator().alphaValue = 1.0
                if motionEnabled {
                    hudPanel.animator().setFrame(frame, display: true)
                }
            }
        }

        hudHideTimer?.invalidate()
        if let delay = hideAfter {
            hudHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.hide()
            }
        }
    }

    func hide() {
        hudHideTimer?.invalidate()
        
        if hudPanel.isVisible {
            var frame = hudPanel.frame
            let motionEnabled = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            if motionEnabled { frame.origin.y -= 10 }
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                hudPanel.animator().alphaValue = 0.0
                if motionEnabled {
                    hudPanel.animator().setFrame(frame, display: true)
                }
            }, completionHandler: { [weak self] in
                self?.hudPanel.orderOut(nil)
                self?.stopPulseAnimation()
            })
        }
    }
    
    private func startPulseAnimation() {
        guard !isPulsing && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        isPulsing = true
        
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 0.8
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.15
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        hudIconView.layer?.add(pulseAnimation, forKey: "pulse")
        // Switch to the violet color described in the design doc for recording
        hudIconView.contentTintColor = NSColor(calibratedRed: 0.67, green: 0.38, blue: 1.0, alpha: 1.0) // #AB61FF
    }
    
    private func stopPulseAnimation() {
        isPulsing = false
        hudIconView.layer?.removeAnimation(forKey: "pulse")
    }
}
