# Echoflow

Echoflow is an open-source, private, unlimited desktop dictation application for macOS, built by **Bahumukh**.

This project will be launched to the public at: **[echoflow.bahumukh.com](https://echoflow.bahumukh.com)**.

## Version 1 Workflow

Echoflow provides a global, local, hold-to-dictate workflow designed for low-friction and absolute privacy:

1. **Hold to Dictate**: Press and hold **Option + Space** to start recording from the current cursor in almost any macOS application.
2. **Local Recording & Transcription**: Echoflow records microphone audio only while you deliberately hold the shortcut. It transcribes the audio entirely locally on your Mac using a bundled `whisper.cpp` engine. No audio is ever uploaded to the cloud.
3. **Smart Formatting**: The raw transcript is automatically cleaned up—improving punctuation, capitalization, removing filler words, and applying dictionary replacements or voice commands.
4. **Instant Insertion & Feedback**: A compact floating HUD communicates the listening and transcription state. Once transcribed, the refined text is immediately inserted at your cursor.

## Features

- **Local-first**: Completely private processing. No cloud inference, subscriptions, or API keys required.
- **Low-friction**: Intuitive, global hold-to-talk interaction.
- **Safe keyboard behavior**: Only Option + Space is consumed; your ordinary Space key continues to work normally.
- **Useful output**: Text is automatically corrected for grammar, punctuation, and sentence boundaries before insertion.
- **Small dependency surface**: Uses native macOS frameworks and a bundled static Whisper runtime.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
