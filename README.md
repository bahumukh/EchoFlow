<p align="center">
  <a href="https://echoflow.bahumukh.com">
    <picture>
      <source srcset="https://via.placeholder.com/400x100?text=EchoFlow+Logo" media="(prefers-color-scheme: dark)">
      <source srcset="https://via.placeholder.com/400x100?text=EchoFlow+Logo" media="(prefers-color-scheme: light)">
      <img src="https://via.placeholder.com/400x100?text=EchoFlow+Logo" alt="EchoFlow logo">
    </picture>
  </a>
</p>
<p align="center">An open-source, fully private, unlimited desktop dictation application.</p>
<p align="center">
  <a href="https://github.com/bahumukh/EchoFlow/actions/workflows/build-and-release.yml"><img alt="Build status" src="https://img.shields.io/github/actions/workflow/status/bahumukh/EchoFlow/build-and-release.yml?style=flat-square&branch=main" /></a>
  <a href="https://github.com/bahumukh/EchoFlow/releases/latest"><img alt="Latest Release" src="https://img.shields.io/github/v/release/bahumukh/EchoFlow?style=flat-square" /></a>
  <a href="https://github.com/bahumukh/EchoFlow/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/bahumukh/EchoFlow?style=flat-square" /></a>
</p>

[![EchoFlow Demo](https://via.placeholder.com/1200x600?text=EchoFlow+Screenshot)](https://echoflow.bahumukh.com)

---

### Overview

Echoflow provides a global, low-friction, hold-to-dictate workflow designed for absolute privacy. It runs entirely locally on your machine, ensuring that your audio never leaves your device. 

Instead of relying on Electron or bloated web frameworks, Echoflow uses a **Multi-Native Architecture**. It provides three entirely separate native applications (macOS, Windows, and Linux) that all wrap around a single shared, high-performance `whisper.cpp` C/C++ engine. This ensures the app feels 100% native on every operating system, consumes minimal RAM/battery, and integrates deeply with OS-specific Accessibility APIs for global hotkeys and seamless typing simulation.

### Key Features
- **100% Local & Private**: No cloud inference, subscriptions, or API keys required. Audio processing runs locally.
- **Global Hotkey**: Press and hold a single key anywhere on your OS to start dictating.
- **Instant Insertion**: Your transcribed text is automatically pasted exactly where your cursor is, in any application.
- **Smart Formatting**: Automatically cleans up your transcript, capitalizing sentences and fixing punctuation.
- **Custom Dictionary**: Teach Echoflow your specific industry terms and acronyms via a built-in JSON dictionary.

---

### 💻 Usage (All Platforms)

1. Click on any text field in any application (e.g., Chrome, Slack, VSCode, Notes).
2. **Press and hold** the Dictation Hotkey:
   - **macOS**: `Fn` (Function) key (Customizable in settings)
   - **Windows**: `F12` key
   - **Linux**: `F12` key
3. A sleek, semi-transparent "Listening..." HUD will appear on your screen.
4. Speak naturally.
5. **Release** the key. The HUD will disappear, and within moments, your transcribed text will be automatically pasted right where your cursor is!

---

### Installation

#### macOS (Apple Silicon)
1. Go to the [Releases](https://github.com/bahumukh/EchoFlow/releases/latest) page.
2. Download `Echoflow-macOS.zip` and extract `Echoflow.app` into your **Applications** folder.
3. **Right-click (or Control-click)** the app and select **Open** to bypass Gatekeeper.
4. Grant **Accessibility** and **Microphone** permissions when prompted.

#### Windows (WPF .NET 8)
1. Go to the [Releases](https://github.com/bahumukh/EchoFlow/releases/latest) page.
2. Download `Echoflow-Windows.zip` and extract it to your preferred location.
3. Run `Echoflow.exe`. (If Windows SmartScreen appears, click *More info* -> *Run anyway*).

#### Linux (GTK3 / X11)
1. Go to the [Releases](https://github.com/bahumukh/EchoFlow/releases/latest) page.
2. Download `Echoflow-Linux.zip` and extract it to your preferred location.
3. Make sure X11 and ALSA dependencies are installed (`sudo apt install libgtk-3-dev libasound2-dev libx11-dev libxtst-dev`).
4. Run `./echoflow`. *(Note: Wayland users may need to run this under XWayland).*

---

### Building from Source

Check the dedicated READMEs for each platform for detailed build instructions:
- [macOS Developer Guide](macOS/README.md) *(Uses Xcode and Swift)*
- [Windows Developer Guide](Windows/README.md) *(Uses Visual Studio / .NET 8 SDK)*
- [Linux Developer Guide](Linux/README.md) *(Uses CMake and GCC)*

---

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
