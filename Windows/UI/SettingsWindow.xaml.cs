using System.Linq;
using System.Windows;
using System.Windows.Controls;
using Echoflow.Services;

namespace Echoflow.UI
{
    public partial class SettingsWindow : Window
    {
        public SettingsWindow()
        {
            InitializeComponent();
            LoadSettings();
        }

        private void LoadSettings()
        {
            var settings = SettingsManager.Load();

            // Checkboxes
            ChkAutoPaste.IsChecked = settings.AutoPaste;
            ChkRemoveFillers.IsChecked = settings.RemoveFillers;
            ChkSmartFormatting.IsChecked = settings.SmartFormatting;
            ChkRetainAudio.IsChecked = settings.RetainAudio;

            // Dictation Hotkey
            foreach (ComboBoxItem item in CmbDictationHotkey.Items)
            {
                if (item.Tag != null && int.Parse(item.Tag.ToString()!) == settings.HotkeyCode)
                {
                    CmbDictationHotkey.SelectedItem = item;
                    break;
                }
            }
            if (CmbDictationHotkey.SelectedItem == null)
                CmbDictationHotkey.SelectedIndex = 0;

            // Undo Hotkey
            foreach (ComboBoxItem item in CmbUndoHotkey.Items)
            {
                if (item.Tag != null && int.Parse(item.Tag.ToString()!) == settings.UndoHotkeyCode)
                {
                    CmbUndoHotkey.SelectedItem = item;
                    break;
                }
            }
            if (CmbUndoHotkey.SelectedItem == null)
                CmbUndoHotkey.SelectedIndex = 0;

            // Model
            foreach (ComboBoxItem item in CmbModel.Items)
            {
                if (item.Tag?.ToString() == settings.ActiveModel)
                {
                    CmbModel.SelectedItem = item;
                    break;
                }
            }
            if (CmbModel.SelectedItem == null)
                CmbModel.SelectedIndex = 1; // Default to Small

            UpdateModelStatus();

            // Language
            foreach (ComboBoxItem item in CmbLanguage.Items)
            {
                if (item.Tag?.ToString() == settings.Language)
                {
                    CmbLanguage.SelectedItem = item;
                    break;
                }
            }
            if (CmbLanguage.SelectedItem == null)
                CmbLanguage.SelectedIndex = 0;
        }

        private void UpdateModelStatus()
        {
            if (CmbModel.SelectedItem is ComboBoxItem modelItem)
            {
                string? modelFile = modelItem.Tag?.ToString();
                if (modelFile != null)
                {
                    string? path = ModelManager.GetModelPath(modelFile);
                    if (path != null)
                    {
                        BtnModelAction.Content = "✓ Available";
                        BtnModelAction.IsEnabled = false;
                        ModelStatusLabel.Text = $"Model found: {System.IO.Path.GetFileName(path)}";
                    }
                    else
                    {
                        BtnModelAction.Content = "Download";
                        BtnModelAction.IsEnabled = true;
                        ModelStatusLabel.Text = "Model not found. Click Download to fetch it.";
                    }
                }
            }
        }

        private async void BtnModelAction_Click(object sender, RoutedEventArgs e)
        {
            if (CmbModel.SelectedItem is not ComboBoxItem modelItem) return;
            string? modelFile = modelItem.Tag?.ToString();
            if (modelFile == null) return;

            var modelType = ModelManager.FromFileName(modelFile);
            if (modelType == null) return;

            BtnModelAction.Content = "Downloading...";
            BtnModelAction.IsEnabled = false;
            ModelProgress.Visibility = Visibility.Visible;
            ModelProgress.Value = 0;

            await ModelManager.DownloadModelAsync(
                modelType.Value,
                progress =>
                {
                    Dispatcher.Invoke(() =>
                    {
                        ModelProgress.Value = progress * 100;
                        ModelStatusLabel.Text = $"Downloading... {progress:P0}";
                    });
                },
                (success, error) =>
                {
                    Dispatcher.Invoke(() =>
                    {
                        ModelProgress.Visibility = Visibility.Collapsed;
                        if (success)
                        {
                            ModelStatusLabel.Text = "Download complete!";
                            BtnModelAction.Content = "✓ Available";
                            BtnModelAction.IsEnabled = false;
                        }
                        else
                        {
                            ModelStatusLabel.Text = $"Download failed: {error}";
                            BtnModelAction.Content = "Retry Download";
                            BtnModelAction.IsEnabled = true;
                        }
                    });
                }
            );
        }

        private void BtnDictionary_Click(object sender, RoutedEventArgs e)
        {
            var dictionaryWindow = new DictionaryWindow();
            dictionaryWindow.Owner = this;
            dictionaryWindow.ShowDialog();
        }

        private void BtnHistory_Click(object sender, RoutedEventArgs e)
        {
            var historyWindow = new HistoryWindow();
            historyWindow.Owner = this;
            historyWindow.ShowDialog();
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            var settings = SettingsManager.Load();

            // Checkboxes
            settings.AutoPaste = ChkAutoPaste.IsChecked ?? true;
            settings.RemoveFillers = ChkRemoveFillers.IsChecked ?? true;
            settings.SmartFormatting = ChkSmartFormatting.IsChecked ?? true;
            settings.RetainAudio = ChkRetainAudio.IsChecked ?? false;

            // Hotkeys
            if (CmbDictationHotkey.SelectedItem is ComboBoxItem hotkeyItem)
                settings.HotkeyCode = int.Parse(hotkeyItem.Tag!.ToString()!);

            if (CmbUndoHotkey.SelectedItem is ComboBoxItem undoItem)
                settings.UndoHotkeyCode = int.Parse(undoItem.Tag!.ToString()!);

            // Model
            if (CmbModel.SelectedItem is ComboBoxItem modelItem)
            {
                settings.ActiveModel = modelItem.Tag!.ToString()!;
                settings.Model = settings.ActiveModel;
            }

            // Language
            if (CmbLanguage.SelectedItem is ComboBoxItem langItem)
                settings.Language = langItem.Tag!.ToString()!;

            SettingsManager.Save(settings);

            // Notify the application to reload settings
            if (System.Windows.Application.Current is App app)
            {
                app.ReloadSettings();
            }

            this.Close();
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }
    }
}
