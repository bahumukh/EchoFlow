# Echoflow

Echoflow is an open-source, fully private, unlimited desktop dictation application built by **Bahumukh**.

This project will be launched to the public at: **[echoflow.bahumukh.com](https://echoflow.bahumukh.com)**.

## Overview
Echoflow provides a global, low-friction, hold-to-dictate workflow designed for absolute privacy. It runs entirely locally on your machine, ensuring that your audio never leaves your device. 

Instead of relying on Electron or bloated web frameworks, Echoflow uses a **Multi-Native Architecture**. It provides three entirely separate native applications (macOS, Windows, and Linux) that all wrap around a single shared, high-performance `whisper.cpp` C/C++ engine. This ensures the app feels 100% native on every operating system, consumes minimal RAM/battery, and integrates deeply with OS-specific Accessibility APIs for global hotkeys and seamless typing simulation.

## Key Features
- **100% Local & Private**: No cloud inference, subscriptions, or API keys required. Audio processing runs locally.
- **Global Hotkey**: Press and hold a single key anywhere on your OS to start dictating.
- **Instant Insertion**: Your transcribed text is automatically pasted exactly where your cursor is, in any application.
- **Smart Formatting**: Automatically cleans up your transcript, capitalizing sentences and fixing punctuation.
- **Custom Dictionary**: Teach Echoflow your specific industry terms and acronyms via a built-in JSON dictionary.

---

## 💻 Usage (All Platforms)

1. Click on any text field in any application (e.g., Chrome, Slack, VSCode, Notes).
2. **Press and hold** the Dictation Hotkey:
   - **macOS**: `Fn` (Function) key (Customizable in settings)
   - **Windows**: `F12` key
   - **Linux**: `F12` key
3. A sleek, semi-transparent "Listening..." HUD will appear on your screen.
4. Speak naturally.
5. **Release** the key. The HUD will disappear, and within moments, your transcribed text will be automatically pasted right where your cursor is!

---

## 🍏 macOS

The macOS client is a native Swift/AppKit application optimized for Apple Silicon.

### System Requirements
- macOS 14 (Sonoma) or newer.
- Apple Silicon Mac (M1, M2, M3, M4). Intel Macs are currently not supported.

### Installation (Pre-built Release)
1. Go to the **Releases** page on this GitHub repository.
2. Download the latest `Echoflow-macOS.zip` file.
3. Extract and drag `Echoflow.app` into your **Applications** folder.
4. **Right-click (or Control-click)** the app and select **Open** to bypass Gatekeeper.
5. Grant **Accessibility** and **Microphone** permissions when prompted.

### Building from Source
1. Clone the repository and navigate to the root directory.
2. Run the automated installation script:
   ```bash
   ./macOS/scripts/install-app.sh
   ```
   *(This will compile the Swift code, download the Whisper AI models, package the `.app` bundle, and install it into your `~/Applications` directory.)*

---

## 🪟 Windows (C# / WPF)

The Windows client is a native `.NET 8.0` WPF application utilizing `NAudio` for recording and `Win32` APIs for global keystroke interception and injection.

### System Requirements
- Windows 10 or Windows 11.
- [.NET 8.0 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0).

### Building from Source
1. Clone the repository and ensure you have the `.NET 8.0 SDK` installed.
2. First, download the shared AI models and build the `whisper.cpp` runtime (Requires CMake/C++ compiler):
   ```cmd
   cd Vendor\whisper.cpp
   cmake -B build
   cmake --build build --config Release
   ```
   *(Make sure to copy the resulting `whisper-cli.exe` and a `.bin` model into the root `Runtime/` and `Runtime/models/` folders respectively).*
3. Navigate to the Windows project directory:
   ```cmd
   cd Windows
   dotnet restore
   dotnet run
   ```

---

## 🐧 Linux (C++ / GTK)

The Linux client is a native `C++17` application utilizing `GTK3` for the UI, `ALSA` for low-level audio capture, and `X11/XTest` for global keystroke interception.

> **Note on Wayland**: Because Wayland explicitly prevents applications from globally grabbing keys or simulating keystrokes for security reasons, Echoflow relies on X11 APIs. Wayland users may need to run this under XWayland, or manually map compositor shortcuts to trigger it via IPC.

### System Requirements
- Ubuntu, Debian, or any modern Linux distribution running an X11 server.

### Building from Source
1. Install the required dependencies:
   ```bash
   sudo apt update
   sudo apt install build-essential cmake libgtk-3-dev libasound2-dev libx11-dev libxtst-dev
   ```
2. Clone the repository and navigate to the Linux project directory:
   ```bash
   cd Linux
   mkdir build && cd build
   cmake ..
   make
   ```
3. Run the application:
   ```bash
   ./echoflow
   ```

---

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
