using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace Echoflow.Services
{
    public class WhisperService
    {
        private readonly string _whisperExePath;
        private readonly string _modelPath;

        public WhisperService()
        {
            // Resolve paths relative to the executable
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            _whisperExePath = Path.Combine(baseDir, "..", "..", "..", "..", "Runtime", "whisper-cli.exe");
            _modelPath = Path.Combine(baseDir, "..", "..", "..", "..", "Runtime", "models", "ggml-small.en.bin");
        }

        public async Task<string?> TranscribeAsync(string audioFilePath)
        {
            if (!File.Exists(_whisperExePath) || !File.Exists(_modelPath) || !File.Exists(audioFilePath))
            {
                return null;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = _whisperExePath,
                Arguments = $"-m \"{_modelPath}\" -f \"{audioFilePath}\" -nt",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = startInfo };
            process.Start();

            string output = await process.StandardOutput.ReadToEndAsync();
            await process.WaitForExitAsync();

            // Cleanup temp audio file
            try
            {
                File.Delete(audioFilePath);
            }
            catch { }

            return output.Trim();
        }
    }
}
