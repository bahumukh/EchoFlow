using System;
using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Forms;
using Echoflow.Services;
using Echoflow.UI;
using System.Threading.Tasks;
using System.Media;

namespace Echoflow
{
    public partial class App : System.Windows.Application
    {
        private NotifyIcon? _notifyIcon;
        private GlobalHotkeyService? _hotkeyService;
        private HUDWindow? _hudWindow;
        private SettingsWindow? _settingsWindow;
        private AudioRecorderService? _audioRecorder;
        private WhisperService? _whisperService;
        private TextInserterService? _textInserter;

        private bool _isRecording = false;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Hide main window entirely
            this.MainWindow = new Window()
            {
                Title = "Echoflow Background",
                ShowInTaskbar = false,
                Visibility = Visibility.Hidden,
                WindowStyle = WindowStyle.None,
                AllowsTransparency = true,
                Width = 0,
                Height = 0
            };

            InitializeServices();
            CreateSystemTray();

            // Run on UI thread to ensure it's created properly
            Dispatcher.Invoke(() => {
                _hudWindow = new HUDWindow();
            });

            // Initial startup state
            OpenSettings();
            CheckModelStatusAsync();
        }

        private async void CheckModelStatusAsync()
        {
            var settings = SettingsManager.Load();
            if (!ModelManager.IsModelAvailable(ModelManager.FromFileName(settings.ActiveModel) ?? ModelManager.ModelType.Small))
            {
                System.Windows.MessageBox.Show(
                    "Echoflow requires a local AI model to run. Please download it from the Settings window.",
                    "Echoflow Setup",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information
                );
                OpenSettings();
            }
        }

        private void InitializeServices()
        {
            _audioRecorder = new AudioRecorderService();
            _whisperService = new WhisperService();
            _textInserter = new TextInserterService();

            _hotkeyService = new GlobalHotkeyService();
            _hotkeyService.OnHotkeyDown += HotkeyService_OnHotkeyDown;
            _hotkeyService.OnHotkeyUp += HotkeyService_OnHotkeyUp;
            _hotkeyService.OnUndoHotkey += HotkeyService_OnUndoHotkey;
        }

        public void ReloadSettings()
        {
            _hotkeyService?.ReloadSettings();
            
            // Re-check model readiness if it was changed
            if (_whisperService != null && !_whisperService.IsReady)
            {
                 // They might have selected a model that isn't downloaded yet.
                 // We don't nag here, but it will error on dictation.
            }
        }

        private void CreateSystemTray()
        {
            _notifyIcon = new NotifyIcon
            {
                Icon = SystemIcons.Application,
                Visible = true,
                Text = "Echoflow"
            };

            var menu = new ContextMenuStrip();
            
            var settingsItem = new ToolStripMenuItem("Settings");
            settingsItem.Click += (s, args) => OpenSettings();
            menu.Items.Add(settingsItem);
            
            var dictionaryItem = new ToolStripMenuItem("Custom Dictionary");
            dictionaryItem.Click += (s, args) => {
                Dispatcher.Invoke(() => {
                    var win = new DictionaryWindow();
                    win.Show();
                });
            };
            menu.Items.Add(dictionaryItem);

            var historyItem = new ToolStripMenuItem("History");
            historyItem.Click += (s, args) => {
                Dispatcher.Invoke(() => {
                    var win = new HistoryWindow();
                    win.Show();
                });
            };
            menu.Items.Add(historyItem);

            menu.Items.Add(new ToolStripSeparator());

            var exitItem = new ToolStripMenuItem("Quit");
            exitItem.Click += (s, args) => ExitApplication();
            menu.Items.Add(exitItem);

            _notifyIcon.ContextMenuStrip = menu;
            _notifyIcon.DoubleClick += (s, args) => OpenSettings();
        }

        private void OpenSettings()
        {
            Dispatcher.Invoke(() =>
            {
                if (_settingsWindow == null || !_settingsWindow.IsLoaded)
                {
                    _settingsWindow = new SettingsWindow();
                    _settingsWindow.Show();
                }
                else
                {
                    _settingsWindow.Activate();
                }
            });
        }

        private void HotkeyService_OnHotkeyDown()
        {
            if (_isRecording) return;
            _isRecording = true;

            if (_whisperService == null || !_whisperService.IsReady)
            {
                Dispatcher.Invoke(() => {
                    _hudWindow?.Show(HUDWindow.HUDState.Error, "AI Model missing.", "Download in settings", 3);
                });
                _isRecording = false;
                return;
            }

            SystemSounds.Beep.Play(); // Play a short beep to indicate listening

            Dispatcher.Invoke(() => {
                _hudWindow?.ResetWaveform();
                _hudWindow?.Show(HUDWindow.HUDState.Listening);
            });

            _audioRecorder!.LevelHandler = level => {
                Dispatcher.Invoke(() => _hudWindow?.AddLevel(level));
            };

            _audioRecorder.StartRecording();
        }

        private async void HotkeyService_OnHotkeyUp()
        {
            if (!_isRecording) return;
            _isRecording = false;

            var (audioPath, duration) = _audioRecorder!.StopRecording();

            if (duration < 0.5)
            {
                Dispatcher.Invoke(() => _hudWindow?.HideHUD());
                return; // Too short to process
            }

            Dispatcher.Invoke(() => {
                _hudWindow?.Show(HUDWindow.HUDState.Transcribing);
            });

            if (audioPath == null)
            {
                Dispatcher.Invoke(() => _hudWindow?.Show(HUDWindow.HUDState.Error, "Audio recording failed.", "", 2));
                return;
            }

            // Transcribe
            string? rawText = await _whisperService!.TranscribeAsync(audioPath);

            if (string.IsNullOrEmpty(rawText))
            {
                Dispatcher.Invoke(() => _hudWindow?.Show(HUDWindow.HUDState.Error, "No speech detected.", "", 2));
                CleanupAudio(audioPath);
                return;
            }

            // Process text through pipeline
            var settings = SettingsManager.Load();
            var processorSettings = new TextProcessorService.ProcessingSettings
            {
                RemoveFillers = settings.RemoveFillers,
                SmartFormatting = settings.SmartFormatting,
                Dictionary = settings.DictionaryEntries,
                Snippets = settings.SnippetEntries
            };

            // In Windows, finding the active app name requires more interop. We'll leave it empty for now,
            // which just disables the messaging app period removal feature.
            var result = TextProcessorService.ProcessText(rawText, processorSettings, "");

            if (string.IsNullOrEmpty(result.Text))
            {
                Dispatcher.Invoke(() => _hudWindow?.Show(HUDWindow.HUDState.Error, "Transcription empty.", "", 2));
                CleanupAudio(audioPath);
                return;
            }

            // Auto Paste vs Clipboard
            if (settings.AutoPaste)
            {
                bool success = false;
                Dispatcher.Invoke(() => {
                    success = _textInserter!.InsertText(result.Text);
                });

                if (result.PressEnter && success)
                {
                    // Small delay before pressing enter
                    await Task.Delay(100);
                    _textInserter!.PressEnter();
                }

                Dispatcher.Invoke(() => _hudWindow?.Show(HUDWindow.HUDState.Success, "", "", 1.5));
            }
            else
            {
                Dispatcher.Invoke(() => {
                    System.Windows.Clipboard.SetText(result.Text);
                    _hudWindow?.Show(HUDWindow.HUDState.Clipboard, "", "", 2.0);
                });
            }

            // Save to history
            var historyEntry = new HistoryEntry
            {
                Id = Guid.NewGuid().ToString(),
                CreatedAt = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                RawText = rawText,
                FinalText = result.Text,
                ApplicationName = "Active Window", // TODO: Fetch foreground window name
                Duration = duration,
                AudioPath = settings.RetainAudio ? audioPath : null
            };
            SettingsManager.AddHistoryEntry(historyEntry);

            if (!settings.RetainAudio)
            {
                CleanupAudio(audioPath);
            }
        }

        private void HotkeyService_OnUndoHotkey()
        {
            Dispatcher.Invoke(() => {
                _hudWindow?.Show(HUDWindow.HUDState.Info, "Undo applied", "", 1.5);
            });
        }

        private void CleanupAudio(string? audioPath)
        {
            if (!string.IsNullOrEmpty(audioPath))
            {
                try { File.Delete(audioPath); } catch { }
            }
        }

        private void ExitApplication()
        {
            _notifyIcon?.Dispose();
            _hotkeyService?.Dispose();
            System.Windows.Application.Current.Shutdown();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            _notifyIcon?.Dispose();
            _hotkeyService?.Dispose();
            base.OnExit(e);
        }
    }
}
