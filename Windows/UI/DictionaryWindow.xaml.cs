using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;
using Echoflow.Services;

namespace Echoflow.UI
{
    public partial class DictionaryWindow : Window
    {
        private ObservableCollection<DictionaryEntry> _entries;

        public DictionaryWindow()
        {
            InitializeComponent();
            var settings = SettingsManager.Load();
            _entries = new ObservableCollection<DictionaryEntry>(
                settings.DictionaryEntries.Select(e => new DictionaryEntry
                {
                    Spoken = e.Spoken,
                    Replacement = e.Replacement,
                    Priority = e.Priority
                })
            );
            DgDictionary.ItemsSource = _entries;
        }

        private void BtnAdd_Click(object sender, RoutedEventArgs e)
        {
            _entries.Add(new DictionaryEntry { Spoken = "", Replacement = "", Priority = false });
        }

        private void BtnRemove_Click(object sender, RoutedEventArgs e)
        {
            if (DgDictionary.SelectedItem is DictionaryEntry selected)
            {
                _entries.Remove(selected);
            }
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            var settings = SettingsManager.Load();
            settings.DictionaryEntries = _entries
                .Where(e => !string.IsNullOrWhiteSpace(e.Spoken))
                .ToList();
            SettingsManager.Save(settings);
            this.Close();
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }
    }
}
