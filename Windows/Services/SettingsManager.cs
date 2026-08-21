using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;

namespace Echoflow.Services
{
    public class DictionaryEntry
    {
        public string Spoken { get; set; } = "";
        public string Replacement { get; set; } = "";
        public bool Priority { get; set; } = false;
    }

    public class SnippetEntry
    {
        public string Trigger { get; set; } = "";
        public string Expansion { get; set; } = "";
    }

    public class AppSettings
    {
        // Hotkeys
        public int HotkeyCode { get; set; } = 0x7B; // F12
        public int UndoHotkeyCode { get; set; } = 0; // Disabled by default

        // Model
        public string Model { get; set; } = "ggml-base.en.bin";
        public string ActiveModel { get; set; } = "ggml-base.en.bin";

        // Language
        public string Language { get; set; } = "en";

        // Processing
        public bool RemoveFillers { get; set; } = true;
        public bool SmartFormatting { get; set; } = true;
        public bool AutoPaste { get; set; } = true;
        public bool RetainAudio { get; set; } = false;

        // Dictionary & Snippets
        public List<DictionaryEntry> DictionaryEntries { get; set; } = new()
        {
            new() { Spoken = "whisper flow", Replacement = "Echoflow", Priority = false },
            new() { Spoken = "API", Replacement = "API", Priority = true }
        };

        public List<SnippetEntry> SnippetEntries { get; set; } = new()
        {
            new() { Trigger = "my email", Expansion = "your.email@example.com" },
            new() { Trigger = "organize my thoughts", Expansion = "Please organize the following thoughts into a concise, structured response:" }
        };

        // History
        public List<HistoryEntry> History { get; set; } = new();
    }

    public class HistoryEntry
    {
        public string Id { get; set; } = "";
        public double CreatedAt { get; set; }
        public string RawText { get; set; } = "";
        public string FinalText { get; set; } = "";
        public string ApplicationName { get; set; } = "";
        public double Duration { get; set; }
        public string? AudioPath { get; set; }
    }

    public static class SettingsManager
    {
        private static readonly string AppDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Echoflow"
        );

        private static readonly string SettingsPath = Path.Combine(AppDir, "settings.json");
        private static readonly string HistoryPath = Path.Combine(AppDir, "history.json");
        public static readonly string RecordingsDir = Path.Combine(AppDir, "Recordings");
        public static readonly string ModelsDir = Path.Combine(AppDir, "Models");

        private static AppSettings? _cached;

        public static AppSettings Load()
        {
            if (_cached != null) return _cached;

            try
            {
                Directory.CreateDirectory(AppDir);
                Directory.CreateDirectory(RecordingsDir);
                Directory.CreateDirectory(ModelsDir);

                if (File.Exists(SettingsPath))
                {
                    string json = File.ReadAllText(SettingsPath);
                    _cached = JsonConvert.DeserializeObject<AppSettings>(json) ?? new AppSettings();
                }
                else
                {
                    _cached = new AppSettings();
                    Save(_cached);
                }
            }
            catch
            {
                _cached = new AppSettings();
            }

            // Load history separately
            try
            {
                if (File.Exists(HistoryPath))
                {
                    string json = File.ReadAllText(HistoryPath);
                    _cached.History = JsonConvert.DeserializeObject<List<HistoryEntry>>(json) ?? new();
                }
            }
            catch { }

            return _cached;
        }

        public static void Save(AppSettings settings)
        {
            try
            {
                _cached = settings;
                Directory.CreateDirectory(AppDir);
                string json = JsonConvert.SerializeObject(settings, Formatting.Indented,
                    new JsonSerializerSettings { NullValueHandling = NullValueHandling.Ignore });
                File.WriteAllText(SettingsPath, json);
            }
            catch { }
        }

        public static void SaveHistory(List<HistoryEntry> history)
        {
            try
            {
                Directory.CreateDirectory(AppDir);
                string json = JsonConvert.SerializeObject(history, Formatting.Indented);
                File.WriteAllText(HistoryPath, json);
            }
            catch { }
        }

        public static void AddHistoryEntry(HistoryEntry entry)
        {
            var settings = Load();
            settings.History.Insert(0, entry);
            if (settings.History.Count > 500)
                settings.History = settings.History.GetRange(0, 500);
            SaveHistory(settings.History);
        }

        public static void ClearHistory()
        {
            var settings = Load();
            settings.History.Clear();
            SaveHistory(settings.History);
        }

        public static void Invalidate()
        {
            _cached = null;
        }
    }
}
