using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using Echoflow.Services;

namespace Echoflow.UI
{
    public partial class HistoryWindow : Window
    {
        public class HistoryViewModel
        {
            public string FinalText { get; set; } = "";
            public string ApplicationName { get; set; } = "";
            public string FormattedDate { get; set; } = "";
            public string FormattedDuration { get; set; } = "";
        }

        private ObservableCollection<HistoryViewModel> _historyItems;

        public HistoryWindow()
        {
            InitializeComponent();
            LoadHistory();
        }

        private void LoadHistory()
        {
            var settings = SettingsManager.Load();
            var items = settings.History.Select(h => new HistoryViewModel
            {
                FinalText = h.FinalText,
                ApplicationName = string.IsNullOrEmpty(h.ApplicationName) ? "Unknown app" : h.ApplicationName,
                FormattedDate = DateTimeOffset.FromUnixTimeSeconds((long)h.CreatedAt).LocalDateTime.ToString("g"),
                FormattedDuration = $"{h.Duration:F1}s"
            });

            _historyItems = new ObservableCollection<HistoryViewModel>(items);
            LstHistory.ItemsSource = _historyItems;
        }

        private void BtnCopy_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string text)
            {
                Clipboard.SetText(text);
                MessageBox.Show("Copied to clipboard!", "Echoflow", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void BtnClear_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Are you sure you want to clear all history?", "Confirm", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                SettingsManager.ClearHistory();
                _historyItems.Clear();
            }
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }
    }
}
