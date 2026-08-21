using System;
using System.Windows;
using Echoflow.Services;
using Echoflow.UI;

namespace Echoflow
{
    public partial class App : System.Windows.Application
    {
        private GlobalHotkeyService? _hotkeyService;
        private AudioRecorderService? _audioService;
        private WhisperService? _whisperService;
        private TextInserterService? _textInserter;
        private HUDWindow? _hud;

        private System.Windows.Forms.NotifyIcon? _notifyIcon;

        private void Application_Startup(object sender, StartupEventArgs e)
        {
            // Initialize Settings and Tray
            SetupSystemTray();

            // Initialize Services
            _audioService = new AudioRecorderService();
            _whisperService = new WhisperService();
            _textInserter = new TextInserterService();
            
            _hud = new HUDWindow();

            _hotkeyService = new GlobalHotkeyService();
            _hotkeyService.OnHotkeyDown += HotkeyService_OnHotkeyDown;
            _hotkeyService.OnHotkeyUp += HotkeyService_OnHotkeyUp;
        }

        private void SetupSystemTray()
        {
            _notifyIcon = new System.Windows.Forms.NotifyIcon
            {
                Icon = System.Drawing.SystemIcons.Information, // Placeholder icon
                Visible = true,
                Text = "Echoflow"
            };

            var contextMenu = new System.Windows.Forms.ContextMenuStrip();
            contextMenu.Items.Add("Settings", null, (s, e) => OpenSettings());
            contextMenu.Items.Add("Quit", null, (s, e) => Shutdown());

            _notifyIcon.ContextMenuStrip = contextMenu;
            _notifyIcon.DoubleClick += (s, e) => OpenSettings();
        }

        private void OpenSettings()
        {
            var settingsWindow = new SettingsWindow();
            settingsWindow.Show();
        }

        public void ReloadSettings()
        {
            _hotkeyService?.ReloadSettings();
            // WhisperService dynamically reads from SettingsManager on every TranscribeAsync call.
        }

        private void HotkeyService_OnHotkeyDown()
        {
            Dispatcher.Invoke(() =>
            {
                _hud?.ShowHUD();
            });
            
            _audioService?.StartRecording();
        }

        private async void HotkeyService_OnHotkeyUp()
        {
            Dispatcher.Invoke(() =>
            {
                _hud?.HideHUD();
            });

            string? audioPath = _audioService?.StopRecording();
            
            if (!string.IsNullOrEmpty(audioPath))
            {
                string? transcribedText = await _whisperService!.TranscribeAsync(audioPath);
                
                if (!string.IsNullOrWhiteSpace(transcribedText))
                {
                    _textInserter?.InsertText(transcribedText);
                }
            }
        }

        protected override void OnExit(ExitEventArgs e)
        {
            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
            }
            _hotkeyService?.Dispose();
            base.OnExit(e);
        }
    }
}
