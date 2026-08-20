# Echoflow

Echoflow is an open-source, private, unlimited desktop dictation application for macOS, built by **Bahumukh**.

This project will be launched to the public at: **[echoflow.bahumukh.com](https://echoflow.bahumukh.com)**.

## Overview
Echoflow provides a global, low-friction, hold-to-dictate workflow designed for absolute privacy. It runs entirely locally on your Apple Silicon Mac, ensuring that your audio never leaves your device. 

## Key Features
- **100% Local & Private**: No cloud inference, subscriptions, or API keys required. Audio processing runs locally using a bundled `whisper.cpp` engine.
- **Customizable Hotkeys**: Choose your preferred global trigger key (Fn, Option, Control, or Command) to hold and speak.
- **Instant Insertion**: Your transcribed text is automatically pasted exactly where your cursor is, in almost any macOS application.
- **Smart Formatting & Fillers**: Automatically cleans up your transcript, capitalizing sentences, fixing punctuation, and stripping filler words (like "um" and "uh").
- **Transcription History & Undo**: Made a mistake? Use your configured Undo Hotkey (like Option+Z) to revert the transcription, or view all your past transcriptions in the built-in History log.
- **Offline AI Models**: Switch between `Base` and `Small` language models dynamically based on your speed and accuracy preferences.
- **Custom Dictionary**: Teach Echoflow your specific industry terms, names, and reusable snippets via a built-in JSON dictionary.

---

## Installation Guide (For Users)

There are absolutely no limits or caps on how many people can download or use Echoflow. To install the app:

### Method 1: Download the Release (Easiest)
1. Go to the **Releases** page on this GitHub repository.
2. Download the latest `Echoflow-v0.1.0.zip` file.
3. Extract the ZIP file.
4. Drag the extracted `Echoflow.app` into your Mac's **Applications** folder.
5. Open `Echoflow` from your Launchpad or Spotlight.
6. The first time you launch the app, you will be prompted to grant **Accessibility** and **Microphone** permissions. (Accessibility is required to paste text into other apps).

### System Requirements
- **macOS 14 (Sonoma)** or newer.
- An **Apple Silicon Mac** (M1, M2, M3, M4). Intel Macs are not supported.

---

## Developer Guide (Building from Source)

If you are a developer and wish to compile the application yourself:

### Prerequisites
- Xcode installed on your Mac.
- Homebrew installed (optional, for dependencies).

### Build Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/bahumukh/EchoFlow.git
   cd EchoFlow
   ```
2. Run the automated installation script. This will compile the Swift code, download the necessary Whisper AI models, package the `.app` bundle, and install it into your `~/Applications` directory:
   ```bash
   ./scripts/install-app.sh
   ```
3. Once completed, the script will automatically launch the newly built app.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
