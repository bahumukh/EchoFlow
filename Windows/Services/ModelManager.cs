using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace Echoflow.Services
{
    /// <summary>
    /// Manages whisper.cpp model files: discovery, download, and selection.
    /// Port of macOS EchoflowModelManager.swift.
    /// </summary>
    public class ModelManager
    {
        public enum ModelType
        {
            Base,
            Small
        }

        public static string GetFileName(ModelType type) => type switch
        {
            ModelType.Base => "ggml-base.en.bin",
            ModelType.Small => "ggml-small.en.bin",
            _ => "ggml-small.en.bin"
        };

        public static string GetDisplayName(ModelType type) => type switch
        {
            ModelType.Base => "Base (Faster, Good Accuracy)",
            ModelType.Small => "Small (Slower, High Accuracy)",
            _ => "Unknown"
        };

        public static string GetDownloadUrl(ModelType type)
        {
            string filename = GetFileName(type);
            return $"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{filename}";
        }

        public static ModelType? FromFileName(string filename)
        {
            return filename switch
            {
                "ggml-base.en.bin" => ModelType.Base,
                "ggml-small.en.bin" => ModelType.Small,
                _ => null
            };
        }

        /// <summary>
        /// Find the model file path. Checks: 1) Downloaded models, 2) Bundled Runtime/models
        /// </summary>
        public static string? GetModelPath(string modelFileName)
        {
            // 1. Check downloaded models in AppData
            string downloadedPath = Path.Combine(SettingsManager.ModelsDir, modelFileName);
            if (File.Exists(downloadedPath))
                return downloadedPath;

            // 2. Check bundled Runtime/models next to exe
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;

            // Production: Runtime/ is next to the exe
            string bundledPath = Path.Combine(baseDir, "Runtime", "models", modelFileName);
            if (File.Exists(bundledPath))
                return bundledPath;

            // Development: walk up
            string devPath = Path.Combine(baseDir, "..", "..", "..", "..", "Runtime", "models", modelFileName);
            if (File.Exists(devPath))
                return Path.GetFullPath(devPath);

            return null;
        }

        /// <summary>
        /// Check if a model is available locally.
        /// </summary>
        public static bool IsModelAvailable(ModelType type)
        {
            return GetModelPath(GetFileName(type)) != null;
        }

        private static CancellationTokenSource? _downloadCts;
        private static bool _isDownloading = false;

        public static bool IsDownloading => _isDownloading;

        /// <summary>
        /// Download a model from HuggingFace with progress reporting.
        /// </summary>
        public static async Task DownloadModelAsync(
            ModelType type,
            Action<double> onProgress,
            Action<bool, string?> onCompletion)
        {
            if (_isDownloading) return;

            _isDownloading = true;
            _downloadCts = new CancellationTokenSource();

            string url = GetDownloadUrl(type);
            string destPath = Path.Combine(SettingsManager.ModelsDir, GetFileName(type));

            try
            {
                Directory.CreateDirectory(SettingsManager.ModelsDir);

                using var httpClient = new HttpClient();
                httpClient.Timeout = TimeSpan.FromHours(2);

                using var response = await httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, _downloadCts.Token);
                response.EnsureSuccessStatusCode();

                long? totalBytes = response.Content.Headers.ContentLength;
                long downloadedBytes = 0;

                string tempPath = destPath + ".tmp";

                using (var contentStream = await response.Content.ReadAsStreamAsync())
                using (var fileStream = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None, 8192, true))
                {
                    byte[] buffer = new byte[8192];
                    int bytesRead;

                    while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length, _downloadCts.Token)) > 0)
                    {
                        await fileStream.WriteAsync(buffer, 0, bytesRead, _downloadCts.Token);
                        downloadedBytes += bytesRead;

                        if (totalBytes.HasValue && totalBytes.Value > 0)
                        {
                            double progress = (double)downloadedBytes / totalBytes.Value;
                            onProgress(progress);
                        }
                    }
                }

                // Move temp to final
                if (File.Exists(destPath))
                    File.Delete(destPath);
                File.Move(tempPath, destPath);

                _isDownloading = false;
                onCompletion(true, null);
            }
            catch (OperationCanceledException)
            {
                _isDownloading = false;
                onCompletion(false, "Download cancelled.");
            }
            catch (Exception ex)
            {
                _isDownloading = false;
                onCompletion(false, ex.Message);
            }
        }

        public static void CancelDownload()
        {
            _downloadCts?.Cancel();
        }
    }
}
