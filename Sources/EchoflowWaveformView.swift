import Cocoa

/// Custom NSView that renders a live audio waveform with smoothed, color-interpolated bars.
/// PRD Section 8.8: 38 samples, smoothing, sine envelope, blue-to-purple gradient.
class EchoflowWaveformView: NSView {

    /// Number of level samples to keep
    private let sampleCount = 38

    /// Stored level samples in [0, 1] range
    private var samples: [CGFloat] = []

    /// Previous smoothed level for temporal smoothing
    private var smoothedLevel: CGFloat = 0

    /// Gap between bars in points
    private let barGap: CGFloat = 3

    /// Minimum computed bar width
    private let minBarWidth: CGFloat = 2.4

    /// Minimum bar height in points
    private let minBarHeight: CGFloat = 3

    // Start color: sRGB (0.28, 0.64, 1.0, 1.0) — blue
    private let startColor = NSColor(srgbRed: 0.28, green: 0.64, blue: 1.0, alpha: 1.0)
    // End color: sRGB (0.67, 0.38, 1.0, 1.0) — purple
    private let endColor = NSColor(srgbRed: 0.67, green: 0.38, blue: 1.0, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        resetSamples()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        resetSamples()
    }

    /// Reset all samples and smoothed level to zero (called when recording starts)
    func resetSamples() {
        samples = Array(repeating: 0, count: sampleCount)
        smoothedLevel = 0
        needsDisplay = true
    }

    /// Add a new level sample. Called from the main queue with audio level in [0, 1].
    func addLevel(_ level: CGFloat) {
        // Clamp to [0, 1]
        let clamped = min(max(level, 0), 1)

        // Smooth: smoothed = previous × 0.68 + new × 0.32
        smoothedLevel = smoothedLevel * 0.68 + clamped * 0.32

        // Drop oldest if at capacity, then append
        if samples.count >= sampleCount {
            samples.removeFirst()
        }
        samples.append(smoothedLevel)

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds
        let count = samples.count
        guard count > 0 else { return }

        // Calculate bar width
        let totalGaps = CGFloat(count - 1) * barGap
        var barWidth = (bounds.width - totalGaps) / CGFloat(count)
        barWidth = max(barWidth, minBarWidth)

        let centerY = bounds.midY

        for i in 0..<count {
            let level = samples[i]

            // Progress through the array [0, 1]
            let progress = count > 1 ? CGFloat(i) / CGFloat(count - 1) : 0.5

            // Sine envelope: 0.62 + 0.38 × sin(progress × π)
            let envelope = 0.62 + 0.38 * sin(progress * .pi)

            // Bar height
            let maxBarHeight = bounds.height - 2
            var barHeight = level * envelope * maxBarHeight
            barHeight = max(barHeight, minBarHeight)

            // Bar position
            let x = CGFloat(i) * (barWidth + barGap)
            let y = centerY - barHeight / 2

            // Interpolate color from start to end
            let r = startColor.redComponent + (endColor.redComponent - startColor.redComponent) * progress
            let g = startColor.greenComponent + (endColor.greenComponent - startColor.greenComponent) * progress
            let b = startColor.blueComponent + (endColor.blueComponent - startColor.blueComponent) * progress

            context.setFillColor(NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0).cgColor)

            // Draw rounded bar
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let cornerRadius = barWidth / 2
            let path = NSBezierPath(roundedRect: barRect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.fill()
        }
    }
}
