using System;
using System.Windows;
using Echoflow.Services;
using Echoflow.UI;

namespace Echoflow
{
    public partial class App : Application
    {
        private GlobalHotkeyService? _hotkeyService;
        private AudioRecorderService? _audioService;
        private WhisperService? _whisperService;
        private TextInserterService? _textInserter;
        private HUDWindow? _hud;

        private void Application_Startup(object sender, StartupEventArgs e)
        {
            // Initialize Services
            _audioService = new AudioRecorderService();
            _whisperService = new WhisperService();
            _textInserter = new TextInserterService();
            
            _hud = new HUDWindow();

            _hotkeyService = new GlobalHotkeyService();
            _hotkeyService.OnHotkeyDown += HotkeyService_OnHotkeyDown;
            _hotkeyService.OnHotkeyUp += HotkeyService_OnHotkeyUp;
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
            _hotkeyService?.Dispose();
            base.OnExit(e);
        }
    }
}
