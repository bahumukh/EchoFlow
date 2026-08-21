using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace Echoflow.Services
{
    public class WhisperService
    {
        private readonly string? _whisperExePath;

        public WhisperService()
        {
            _whisperExePath = DiscoverWhisperCLI();
        }

        private string? DiscoverWhisperCLI()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;

            // Production: Runtime/ next to exe
            string prodPath = Path.Combine(baseDir, "Runtime", "whisper-cli.exe");
            if (File.Exists(prodPath)) return prodPath;

            // Development: walk up
            string devPath = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "..", "..", "Runtime", "whisper-cli.exe"));
            if (File.Exists(devPath)) return devPath;

            return null;
        }

        /// <summary>
        /// Check if the whisper engine is ready.
        /// </summary>
        public bool IsReady
        {
            get
            {
                if (string.IsNullOrEmpty(_whisperExePath) || !File.Exists(_whisperExePath))
                    return false;

                var settings = SettingsManager.Load();
                string? modelPath = ModelManager.GetModelPath(settings.ActiveModel);
                return modelPath != null;
            }
        }

        /// <summary>
        /// Transcribe an audio file using whisper-cli.
        /// Matches macOS runWhisper() method with -otxt output, language flag, and prompt injection.
        /// </summary>
        public async Task<string?> TranscribeAsync(string audioFilePath)
        {
            if (string.IsNullOrEmpty(_whisperExePath) || !File.Exists(_whisperExePath))
                return null;

            var settings = SettingsManager.Load();
            string? modelPath = ModelManager.GetModelPath(settings.ActiveModel);

            if (string.IsNullOrEmpty(modelPath) || !File.Exists(modelPath) || !File.Exists(audioFilePath))
                return null;

            // Create output prefix by replacing .wav with .transcript
            string outputPrefix;
            if (audioFilePath.EndsWith(".wav", StringComparison.OrdinalIgnoreCase))
                outputPrefix = audioFilePath.Substring(0, audioFilePath.Length - 4) + ".transcript";
            else
                outputPrefix = audioFilePath + ".transcript";

            string expectedOutputFile = outputPrefix + ".txt";

            // Delete stale output
            try { File.Delete(expectedOutputFile); } catch { }

            // Build arguments (matching macOS)
            int numThreads = Math.Max(2, Math.Min(8, Environment.ProcessorCount / 2));
            var args = new List<string>
            {
                "-ng",
                "-m", modelPath,
                "-f", audioFilePath,
                "-otxt",
                "-of", outputPrefix,
                "-nt",
                "-np",
                "-t", numThreads.ToString()
            };

            // Language
            if (settings.Language != "auto")
            {
                args.Add("-l");
                args.Add(settings.Language);
            }

            // Prompt injection from dictionary terms
            string promptTerms = BuildPromptTerms(settings);
            if (!string.IsNullOrEmpty(promptTerms))
            {
                args.Add("--prompt");
                args.Add(promptTerms);
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = _whisperExePath,
                Arguments = string.Join(" ", args.Select(a => a.Contains(' ') ? $"\"{a}\"" : a)),
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            try
            {
                using var process = new Process { StartInfo = startInfo };
                process.Start();
                await process.WaitForExitAsync();

                if (process.ExitCode != 0)
                    return null;

                // Read transcript from output file
                if (!File.Exists(expectedOutputFile))
                    return null;

                string transcript = await File.ReadAllTextAsync(expectedOutputFile);

                // Delete .txt file after successful read
                try { File.Delete(expectedOutputFile); } catch { }

                return transcript.Trim();
            }
            catch
            {
                return null;
            }
        }

        /// <summary>
        /// Build prompt terms from dictionary entries (matches macOS buildPromptTerms()).
        /// </summary>
        private string BuildPromptTerms(AppSettings settings)
        {
            var terms = new List<string> { "Echoflow" };

            foreach (var entry in settings.DictionaryEntries)
            {
                if (!string.IsNullOrEmpty(entry.Replacement) && !terms.Contains(entry.Replacement))
                    terms.Add(entry.Replacement);
            }

            return string.Join(". ", terms);
        }
    }
}
