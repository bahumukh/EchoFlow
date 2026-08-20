using System.Windows;

namespace Echoflow.UI
{
    public partial class HUDWindow : Window
    {
        public HUDWindow()
        {
            InitializeComponent();
        }

        public void ShowHUD()
        {
            this.Show();
        }

        public void HideHUD()
        {
            this.Hide();
        }
    }
}
