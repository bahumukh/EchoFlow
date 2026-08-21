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
            
            foreach (ComboBoxItem item in CmbHotkey.Items)
            {
                if (item.Tag != null && int.Parse(item.Tag.ToString()!) == settings.HotkeyCode)
                {
                    CmbHotkey.SelectedItem = item;
                    break;
                }
            }

            foreach (ComboBoxItem item in CmbModel.Items)
            {
                if (item.Tag?.ToString() == settings.Model)
                {
                    CmbModel.SelectedItem = item;
                    break;
                }
            }
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            if (CmbHotkey.SelectedItem is ComboBoxItem hotkeyItem && CmbModel.SelectedItem is ComboBoxItem modelItem)
            {
                var settings = new AppSettings
                {
                    HotkeyCode = int.Parse(hotkeyItem.Tag!.ToString()!),
                    Model = modelItem.Tag!.ToString()!
                };

                SettingsManager.Save(settings);
                
                // Notify the application to reload settings
                if (System.Windows.Application.Current is App app)
                {
                    app.ReloadSettings();
                }

                this.Close();
            }
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }
    }
}
