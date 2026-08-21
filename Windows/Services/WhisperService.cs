using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace Echoflow.Services
{
    public class WhisperService
    {
        private readonly string _whisperExePath;
        private readonly string _baseRuntimePath;

        public WhisperService()
        {
            // Resolve paths relative to the executable
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            
            // Check if Runtime exists directly next to executable (Production ZIP)
            if (Directory.Exists(Path.Combine(baseDir, "Runtime")))
            {
                _baseRuntimePath = Path.Combine(baseDir, "Runtime");
                _whisperExePath = Path.Combine(_baseRuntimePath, "whisper-cli.exe");
            }
            else // Local development fallback
            {
                _baseRuntimePath = Path.Combine(baseDir, "..", "..", "..", "..", "Runtime");
                _whisperExePath = Path.Combine(_baseRuntimePath, "whisper-cli.exe");
            }
        }

        private string GetModelPath()
        {
            var settings = SettingsManager.Load();
            return Path.Combine(_baseRuntimePath, "models", settings.Model);
        }

        public async Task<string?> TranscribeAsync(string audioFilePath)
        {
            string modelPath = GetModelPath();
            
            if (!File.Exists(_whisperExePath) || !File.Exists(modelPath) || !File.Exists(audioFilePath))
            {
                return null;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = _whisperExePath,
                Arguments = $"-m \"{modelPath}\" -f \"{audioFilePath}\" -nt",
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
