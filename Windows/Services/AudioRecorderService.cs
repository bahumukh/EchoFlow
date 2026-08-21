using System;
using System.IO;
using NAudio.Wave;

namespace Echoflow.Services
{
    public class AudioRecorderService
    {
        private WaveInEvent? _waveIn;
        private WaveFileWriter? _writer;
        private string? _currentTempFile;
        private DateTime _recordingStartTime;

        /// <summary>
        /// Callback for audio level updates (value in [0, 1]).
        /// </summary>
        public Action<float>? LevelHandler { get; set; }

        /// <summary>
        /// Duration of the last recording in seconds.
        /// </summary>
        public double Duration { get; private set; }

        /// <summary>
        /// Whether currently recording.
        /// </summary>
        public bool IsRecording { get; private set; }

        public void StartRecording()
        {
            if (IsRecording) return;

            // Save to Echoflow Recordings directory
            string recordingsDir = SettingsManager.RecordingsDir;
            Directory.CreateDirectory(recordingsDir);
            _currentTempFile = Path.Combine(recordingsDir, $"dictation-{Guid.NewGuid()}.wav");

            // whisper.cpp requires 16kHz, 1 channel (mono), 16-bit PCM
            _waveIn = new WaveInEvent
            {
                WaveFormat = new WaveFormat(16000, 16, 1),
                BufferMilliseconds = 50
            };

            _waveIn.DataAvailable += (s, a) =>
            {
                _writer?.Write(a.Buffer, 0, a.BytesRecorded);

                // Calculate RMS level for waveform visualization
                CalculateAndReportLevel(a.Buffer, a.BytesRecorded);
            };

            _waveIn.RecordingStopped += (s, a) =>
            {
                _writer?.Dispose();
                _writer = null;
                _waveIn?.Dispose();
                _waveIn = null;
                IsRecording = false;
                LevelHandler?.Invoke(0);
            };

            _writer = new WaveFileWriter(_currentTempFile, _waveIn.WaveFormat);
            _recordingStartTime = DateTime.Now;
            _waveIn.StartRecording();
            IsRecording = true;
        }

        public (string? audioPath, double duration) StopRecording()
        {
            if (_waveIn != null)
            {
                Duration = (DateTime.Now - _recordingStartTime).TotalSeconds;
                _waveIn.StopRecording();
            }
            return (_currentTempFile, Duration);
        }

        /// <summary>
        /// Calculate RMS level from 16-bit PCM buffer and deliver to handler.
        /// Matches macOS algorithm from EchoflowAudioRecorder.swift.
        /// </summary>
        private void CalculateAndReportLevel(byte[] buffer, int bytesRecorded)
        {
            int sampleCount = bytesRecorded / 2; // 16-bit = 2 bytes per sample
            if (sampleCount == 0) return;

            double sumOfSquares = 0;
            for (int i = 0; i < bytesRecorded; i += 2)
            {
                if (i + 1 < bytesRecorded)
                {
                    short sample = (short)(buffer[i] | (buffer[i + 1] << 8));
                    float normalized = sample / 32768f;
                    sumOfSquares += normalized * normalized;
                }
            }

            float rms = (float)Math.Sqrt(sumOfSquares / sampleCount);

            // Clamp log input
            float clampedRMS = Math.Max(rms, 0.00001f);

            // Convert to dB
            float db = 20 * (float)Math.Log10(clampedRMS);

            // Normalize: (dB + 55) / 55
            float level = (db + 55) / 55;

            // Clamp to [0, 1]
            level = Math.Max(0, Math.Min(1, level));

            LevelHandler?.Invoke(level);
        }
    }
}
