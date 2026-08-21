using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace Echoflow.UI
{
    public partial class HUDWindow : Window
    {
        public enum HUDState
        {
            Listening,
            Transcribing,
            Success,
            Clipboard,
            Error,
            Info
        }

        private DispatcherTimer? _hideTimer;

        private readonly List<System.Windows.Shapes.Rectangle> _waveformBars = new();
        private readonly Queue<float> _levelSamples = new();
        private const int MaxSamples = 48;

        public HUDWindow()
        {
            InitializeComponent();
            BuildWaveformBars();
        }

        private void BuildWaveformBars()
        {
            WaveformCanvas.Children.Clear();
            _waveformBars.Clear();

            double canvasWidth = 372;
            int barCount = MaxSamples;
            double barWidth = 4;
            double gap = (canvasWidth - barCount * barWidth) / (barCount - 1);

            for (int i = 0; i < barCount; i++)
            {
                var bar = new System.Windows.Shapes.Rectangle
                {
                    Width = barWidth,
                    Height = 2,
                    Fill = new SolidColorBrush(System.Windows.Media.Color.FromArgb(180, 120, 90, 255)), // Purple
                    RadiusX = 2,
                    RadiusY = 2
                };
                Canvas.SetLeft(bar, i * (barWidth + gap));
                Canvas.SetBottom(bar, 0);
                WaveformCanvas.Children.Add(bar);
                _waveformBars.Add(bar);
            }
        }

        public void AddLevel(float level)
        {
            _levelSamples.Enqueue(level);
            while (_levelSamples.Count > MaxSamples)
                _levelSamples.Dequeue();

            UpdateWaveform();
        }

        private void UpdateWaveform()
        {
            float[] samples = _levelSamples.ToArray();
            double maxHeight = 28;

            for (int i = 0; i < _waveformBars.Count; i++)
            {
                float sample = i < samples.Length ? samples[i] : 0;
                double height = Math.Max(2, sample * maxHeight);
                _waveformBars[i].Height = height;
            }
        }

        public void ResetWaveform()
        {
            _levelSamples.Clear();
            foreach (var bar in _waveformBars)
                bar.Height = 2;
        }

        public void Show(HUDState state, string message = "", string detail = "", double? hideAfterSeconds = null)
        {
            _hideTimer?.Stop();
            StopPulseAnimation();
            WaveformCanvas.Visibility = Visibility.Collapsed;
            HudSpinner.Visibility = Visibility.Collapsed;

            switch (state)
            {
                case HUDState.Listening:
                    HudIcon.Text = "🎙️";
                    HudTitle.Text = "Listening…";
                    HudDetail.Text = string.IsNullOrEmpty(detail) ? "Release F12 to transcribe and insert" : detail;
                    WaveformCanvas.Visibility = Visibility.Visible;
                    StartPulseAnimation();
                    break;

                case HUDState.Transcribing:
                    HudIcon.Text = "⚙️";
                    HudTitle.Text = "Transcribing locally…";
                    HudDetail.Text = "Audio never leaves this PC";
                    HudSpinner.Visibility = Visibility.Visible;
                    break;

                case HUDState.Success:
                    HudIcon.Text = "✅";
                    HudTitle.Text = "Inserted at cursor";
                    HudDetail.Text = "Processed transcript";
                    PlaySuccessAnimation();
                    break;

                case HUDState.Clipboard:
                    HudIcon.Text = "📋";
                    HudTitle.Text = "Copied to clipboard";
                    HudDetail.Text = "Paste with Ctrl+V";
                    break;

                case HUDState.Error:
                    HudIcon.Text = "⚠️";
                    HudTitle.Text = "Echoflow needs attention";
                    HudDetail.Text = message;
                    break;

                case HUDState.Info:
                    HudIcon.Text = "ℹ️";
                    HudTitle.Text = message;
                    HudDetail.Text = detail;
                    break;
            }

            PositionHUD();

            if (!this.IsVisible)
            {
                this.Show();
                // Slide-up fade-in animation
                var fadeIn = new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(200))
                {
                    EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
                };
                HudBorder.BeginAnimation(OpacityProperty, fadeIn);
            }

            if (hideAfterSeconds.HasValue)
            {
                _hideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(hideAfterSeconds.Value) };
                _hideTimer.Tick += (s, e) => { _hideTimer.Stop(); HideHUD(); };
                _hideTimer.Start();
            }
        }

        public void HideHUD()
        {
            _hideTimer?.Stop();

            if (this.IsVisible)
            {
                var fadeOut = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(180))
                {
                    EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseIn }
                };
                fadeOut.Completed += (s, e) =>
                {
                    this.Hide();
                    StopPulseAnimation();
                };
                HudBorder.BeginAnimation(OpacityProperty, fadeOut);
            }
        }

        private void PositionHUD()
        {
            var screen = SystemParameters.WorkArea;
            this.Left = (screen.Width - this.Width) / 2 + screen.Left;
            this.Top = screen.Height - this.Height - 72 + screen.Top;
        }

        private void StartPulseAnimation()
        {
            var scaleUp = new DoubleAnimation(1.0, 1.15, TimeSpan.FromMilliseconds(800))
            {
                AutoReverse = true,
                RepeatBehavior = RepeatBehavior.Forever,
                EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
            };

            IconScale.BeginAnimation(ScaleTransform.ScaleXProperty, scaleUp);
            IconScale.BeginAnimation(ScaleTransform.ScaleYProperty, scaleUp);
        }

        private void StopPulseAnimation()
        {
            IconScale.BeginAnimation(ScaleTransform.ScaleXProperty, null);
            IconScale.BeginAnimation(ScaleTransform.ScaleYProperty, null);
            IconScale.ScaleX = 1;
            IconScale.ScaleY = 1;
        }

        private void PlaySuccessAnimation()
        {
            var pop = new DoubleAnimationUsingKeyFrames();
            pop.KeyFrames.Add(new EasingDoubleKeyFrame(0.8, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            pop.KeyFrames.Add(new EasingDoubleKeyFrame(1.05, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(150))));
            pop.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(300))));

            IconScale.BeginAnimation(ScaleTransform.ScaleXProperty, pop);
            IconScale.BeginAnimation(ScaleTransform.ScaleYProperty, pop);
        }

        // Keep the old API for backwards compatibility during transition
        public void ShowHUD() => Show(HUDState.Listening);
    }
}
