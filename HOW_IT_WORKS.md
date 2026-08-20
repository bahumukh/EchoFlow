# How Echoflow Works

Echoflow is a native macOS menu bar application written entirely in Swift. It provides system-wide, privacy-first dictation by capturing microphone audio and processing it locally on-device using a bundled Whisper AI model. 

This document breaks down the entire lifecycle of the application—from the moment you press the hotkey to the moment text appears on your screen.

---

## 1. Application Architecture

Echoflow is built using Apple's AppKit framework. The core logic is distributed across several key components:

- **`EchoflowAppDelegate.swift`**: The central brain. It runs as the background agent, manages the Menu Bar icon, intercepts global keyboard shortcuts, and orchestrates the recording and transcription phases.
- **`EchoflowHUDController.swift`**: Controls the floating glassmorphic "Heads Up Display" that appears when you hold the hotkey to provide real-time visual feedback.
- **`EchoflowSettingsWindowController.swift`**: The main user interface for configuring preferences, hotkeys, and text processing rules.
- **`EchoflowModelManager.swift`**: Handles the discovery, downloading, and state management of the localized AI models (Base vs. Small).
- **`whisper.cpp` (Bundled Runtime)**: A high-performance C++ implementation of OpenAI's Whisper model, compiled specifically for Apple Silicon (`arm64`), which handles the actual machine learning inference.

---

## 2. The Dictation Lifecycle

The core value of Echoflow happens in a split-second workflow when a user holds the dictation hotkey.

### Phase A: Interception & Recording
1. **Global Keyboard Monitor**: `EchoflowAppDelegate` uses `NSEvent.addGlobalMonitorForEvents` to constantly listen for the user's configured dictation hotkey (e.g., holding the `Fn` key).
2. **Audio Capture**: When the key is pressed, the app immediately spawns an `AVAudioRecorder` instance. It records microphone input into a temporary 16kHz `.wav` file (the format required by Whisper).
3. **Visual Feedback**: The `EchoflowHUDController` is summoned, displaying a "Listening..." state and a pulsing waveform icon to let the user know their voice is being recorded.

### Phase B: Processing & Transcription
1. **Trigger**: When the user releases the hotkey, the audio recording stops immediately.
2. **Whisper CLI Invocation**: The app spawns a background UNIX `Process` (via `NSTask`) that executes the bundled `whisper-cli` binary. 
3. **Inference**: The CLI is fed the temporary `.wav` file and the path to the active `.bin` model (e.g., `ggml-base.en.bin`). The ML model rapidly transcribes the audio into raw text entirely on the local CPU/GPU (no internet required).

### Phase C: Text Intelligence (Post-Processing)
Before the text is pasted, Echoflow cleans it up. The raw text is passed through several filters:
1. **Smart Formatting**: Applies standard capitalization to the beginning of sentences and ensures correct trailing punctuation.
2. **Filler Removal**: Uses Regular Expressions (Regex) to strip out filler words like *"um"*, *"uh"*, and *"like"* if the user has enabled this setting.
3. **Custom Dictionary**: Scans the text against the user's custom JSON dictionary to replace specific phrases or acronyms (e.g., changing "aws" to "AWS").

### Phase D: Insertion & Cleanup
1. **Clipboard Storage**: The finalized text is temporarily copied to the macOS `NSPasteboard` (the system clipboard).
2. **Simulated Paste**: Echoflow uses macOS Accessibility APIs (`AXUIElement`) or low-level CoreGraphics keyboard events (`CGEvent`) to simulate pressing `Command + V`. This instantly drops the text directly into whichever application the user currently has focused (e.g., Chrome, Notes, Slack).
3. **History Logging**: The text is appended to a local `.json` file managed by `EchoflowHistorySheetController` so the user can review past dictations or use the "Undo" feature.
4. **Cleanup**: The temporary `.wav` file is deleted from the disk to protect user privacy.

---

## 3. Data Storage & Privacy

Because Echoflow is designed to be fully private, it stores data strictly within the user's local Library directory:

- **`~/Library/Application Support/Echoflow/`**: 
  - `settings.json`: Stores user preferences (hotkeys, formatting rules).
  - `dictionary.json`: Stores custom word replacements.
  - `history.json`: Stores the log of recent transcriptions.
  - `/Models/`: Stores any downloaded Whisper AI `.bin` models if they weren't bundled in the initial app release.

At no point does the application make network requests containing user audio or text. The only network request made by the app is when explicitly downloading a new AI model via `URLSession`.
