import Foundation
import AVFoundation

/// Audio recorder for Echoflow.
/// Captures microphone audio, converts to 16 kHz mono Int16 WAV, calculates RMS levels.
/// PRD Sections 9.5 and 9.6.
class EchoflowAudioRecorder {

    /// Callback for audio level updates (value in [0, 1])
    var levelHandler: ((Float) -> Void)?

    /// Whether a recording is currently active
    private(set) var isRecording = false

    /// Duration of the current/last recording in seconds
    private(set) var duration: TimeInterval = 0

    /// The URL of the current recording file
    private(set) var currentURL: URL?

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var converter: AVAudioConverter?
    private var recordingStartTime: Date?

    /// Target format: 16 kHz, Int16, mono, non-interleaved
    private let targetSampleRate: Double = 16000
    private let targetChannels: AVAudioChannelCount = 1
    private let bufferFrameCount: AVAudioFrameCount = 2048

    /// Start recording to the specified URL
    /// - Parameter url: File URL for the WAV output
    /// - Throws: Errors from AVAudioEngine setup
    func start(at url: URL) throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // FR-AUDIO-002: Read the device's output format for bus 0 as the source format
        let sourceFormat = inputNode.outputFormat(forBus: 0)

        guard sourceFormat.sampleRate > 0 else {
            throw NSError(domain: "Echoflow", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Selected microphone format unsupported"])
        }

        // FR-AUDIO-003: Target format — signed 16-bit PCM, 16,000 Hz, mono, non-interleaved
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: false
        ) else {
            throw NSError(domain: "Echoflow", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot create target audio format"])
        }

        // Create converter
        guard let audioConverter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw NSError(domain: "Echoflow", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot create audio converter"])
        }

        // Create output file
        let file = try AVAudioFile(forWriting: url, settings: targetFormat.settings, commonFormat: targetFormat.commonFormat, interleaved: targetFormat.isInterleaved)

        self.audioEngine = engine
        self.audioFile = file
        self.converter = audioConverter
        self.currentURL = url
        self.recordingStartTime = Date()
        self.duration = 0

        // FR-AUDIO-004: Install input tap on bus 0 with 2,048-frame buffer
        inputNode.installTap(onBus: 0, bufferSize: bufferFrameCount, format: sourceFormat) {
            [weak self] (buffer, _) in
            guard let self = self else { return }

            // FR-AUDIO-006/9.6: Calculate RMS level from source buffer
            self.calculateAndReportLevel(buffer: buffer)

            // FR-AUDIO-005: Allocate conversion output capacity
            let inputFrames = buffer.frameLength
            let ratio = self.targetSampleRate / sourceFormat.sampleRate
            let outputCapacity = AVAudioFrameCount(ceil(Double(inputFrames) * ratio) + 32)

            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
                return
            }

            // Convert
            var error: NSError?
            var allConsumed = false
            let status = audioConverter.convert(to: outputBuffer, error: &error) { _, outStatus in
                if allConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                allConsumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            // FR-AUDIO-006: Write successfully converted non-empty buffers
            if status == .haveData && outputBuffer.frameLength > 0 {
                do {
                    try file.write(from: outputBuffer)
                } catch {
                    // Silent write error per baseline behavior
                }
            }
        }

        try engine.start()
        isRecording = true
    }

    /// Stop recording and clean up
    /// - Returns: The duration of the recording, or nil if not recording
    @discardableResult
    func stop() -> TimeInterval? {
        guard isRecording else { return nil }

        // FR-AUDIO-009: Remove tap, stop engine, release references, clear start time, send zero level
        let inputNode = audioEngine?.inputNode
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()

        // Calculate final duration
        if let start = recordingStartTime {
            duration = Date().timeIntervalSince(start)
        }

        // Release references
        audioFile = nil
        converter = nil
        audioEngine = nil
        recordingStartTime = nil
        isRecording = false

        // Send zero level
        levelHandler?(0)

        return duration
    }

    /// Calculate RMS level and deliver to handler
    /// PRD Section 9.6
    private func calculateAndReportLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        // Step 1: Calculate RMS amplitude of channel 0
        let data = channelData[0]
        var sumOfSquares: Float = 0
        for i in 0..<frames {
            let sample = data[i]
            sumOfSquares += sample * sample
        }
        let rms = sqrt(sumOfSquares / Float(frames))

        // Step 2: Clamp log input to at least 0.00001
        let clampedRMS = max(rms, 0.00001)

        // Step 3: Convert to dB: 20 × log10(rms)
        let db = 20 * log10(clampedRMS)

        // Step 4: Normalize: (dB + 55) / 55
        var normalized = (db + 55) / 55

        // Step 5: Clamp to [0, 1]
        normalized = min(max(normalized, 0), 1)

        // Step 6: Deliver to handler
        levelHandler?(normalized)
    }
}
