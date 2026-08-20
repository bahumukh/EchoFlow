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

        public void StartRecording()
        {
            _currentTempFile = Path.Combine(Path.GetTempPath(), $"echoflow_{Guid.NewGuid()}.wav");

            // whisper.cpp requires 16kHz, 1 channel (mono), 16-bit PCM
            _waveIn = new WaveInEvent
            {
                WaveFormat = new WaveFormat(16000, 16, 1)
            };

            _waveIn.DataAvailable += (s, a) =>
            {
                _writer?.Write(a.Buffer, 0, a.BytesRecorded);
            };

            _waveIn.RecordingStopped += (s, a) =>
            {
                _writer?.Dispose();
                _writer = null;
                _waveIn?.Dispose();
                _waveIn = null;
            };

            _writer = new WaveFileWriter(_currentTempFile, _waveIn.WaveFormat);
            _waveIn.StartRecording();
        }

        public string? StopRecording()
        {
            if (_waveIn != null)
            {
                _waveIn.StopRecording();
            }
            return _currentTempFile;
        }
    }
}
