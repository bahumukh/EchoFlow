# Echoflow Product Requirements Document

## Product and technical reconstruction specification

| Field | Value |
|---|---|
| Product | Echoflow |
| Baseline product version | 0.2.2 |
| Baseline bundle build | 7 |
| Document status | Rebuild-ready source of truth |
| Document date | 2026-08-20 |
| Baseline platform | Apple Silicon macOS 14 or newer |
| Bundle identifier | `app.echoflow.desktop` |
| Installed location | `~/Applications/Echoflow.app` |
| Source implementation | Native Swift/AppKit |
| Speech engine | `whisper.cpp` CLI v1.9.1 |
| Default model | `ggml-small.en.bin` |
| Processing model | Fully local; no cloud inference |

---

## 1. Purpose of this document

This document is the complete product requirements document and technical reconstruction specification for Echoflow 0.2.2. It is intended to let a developer or an AI coding agent rebuild Echoflow on another Mac without relying on undocumented knowledge from the original development session.

This PRD has four jobs:

1. Define what Echoflow is, who it serves, and what the product must do.
2. Specify the exact observable behavior of the current 0.2.2 application.
3. Describe the implementation, data, build, packaging, permission, and runtime contracts in enough detail to reproduce the application.
4. Separate baseline requirements from known limitations and future opportunities so a rebuild remains behaviorally compatible.

When this document and the existing source disagree, use the checked-in source as the authority for the current 0.2.2 baseline. When rebuilding without the source, treat all requirements marked **MUST** as mandatory compatibility requirements.

## 2. How to use this PRD with an AI coding agent

Give the AI agent this file and instruct it to implement the milestones in Section 22 in order. The agent should not replace native/local components with cloud services, introduce Electron, change the shortcut semantics, or change the persistence schema unless explicitly requested.

The rebuild should be considered complete only when:

- Every baseline acceptance criterion in Section 20 passes.
- The automated text-processing test vectors in Section 19 pass exactly.
- Ordinary Space input is never swallowed by the global shortcut listener.
- Dictation, transcription, formatting, and insertion work without a network connection after engine setup.
- The built app has the bundle identity, file layout, settings behavior, and user-visible copy described here.

## 3. Executive summary

Echoflow is a private, unlimited desktop dictation application for macOS. The user holds **Option + Space**, speaks, and releases the shortcut. Echoflow records microphone audio, converts it to a Whisper-compatible WAV file, transcribes it locally with a bundled `whisper.cpp` executable and model, improves the text using a deterministic formatting pipeline, and inserts it at the current cursor. A compact floating HUD communicates listening and transcription state.

The application is designed around five core principles:

- **Local-first:** recorded speech and transcripts are processed on the Mac.
- **Low-friction:** dictation is a hold-to-talk global interaction.
- **Safe keyboard behavior:** only Option + Space is consumed; ordinary Space must pass through unchanged.
- **Useful output:** punctuation, capitalization, filler removal, voice commands, dictionary replacements, snippets, and light grammar correction happen automatically.
- **Small dependency surface:** the app uses native macOS frameworks and a bundled static Whisper runtime. Homebrew, Python, API keys, accounts, and cloud services are not runtime dependencies.

## 4. Product problem

Typing is slow or inconvenient when the user wants to capture a thought, write a message, or enter text into an arbitrary desktop application. Built-in dictation tools may have cloud, quota, account, privacy, formatting, or interaction limitations. General-purpose speech-to-text engines also tend to return raw transcripts that still require punctuation and cleanup.

Echoflow solves this by providing a global, local, hold-to-dictate workflow that:

- works from the current cursor in another application;
- records only while the user deliberately holds the shortcut;
- transcribes without uploading audio;
- cleans common spoken-language artifacts;
- gives immediate visual feedback; and
- remains usable without subscriptions or usage quotas.

## 5. Product goals

### 5.1 Primary goals

1. The user can dictate into almost any macOS text field using Option + Space.
2. The user can continue using the ordinary Space key normally in every application.
3. Audio and transcript processing remain local after initial engine/model setup.
4. The resulting text has useful punctuation, sentence boundaries, capitalization, and common corrections.
5. The app has a visible, understandable settings window and remains available from the menu bar when that window is closed.
6. The application can be built using Apple Command Line Tools plus project-owned scripts.
7. Runtime files are bundled into the app so the installed application does not depend on the source tree.

### 5.2 Secondary goals

- Support multiple Whisper language modes and English/multilingual model variants.
- Support user-defined replacements and reusable snippets.
- Keep a bounded local transcript history.
- Optionally retain source recordings.
- Support a voice command that submits the inserted text by pressing Return.

### 5.3 Non-goals for the 0.2.2 baseline

The following are explicitly outside the current baseline:

- Windows or Linux support.
- Cloud transcription or cloud-based grammar correction.
- Wispr Flow account, license, API, or service integration.
- Circumvention of third-party subscriptions or licensing.
- A transcript-history browser UI.
- User-configurable keyboard shortcuts.
- Automatic launch at login.
- Automatic application updates.
- Mac App Store packaging, Developer ID distribution, notarization, or hardened runtime.
- Multiple simultaneous recordings.
- Streaming partial transcripts while the user is speaking.
- A cancel button for an in-progress Whisper task.
- A local large-language-model grammar rewrite.

## 6. Target user and core jobs

### 6.1 Primary user

A Mac user who frequently writes messages, notes, prompts, documents, or forms and wants fast speech-driven text input without sending audio to a cloud service.

### 6.2 Core jobs to be done

- "When my cursor is in a text field, let me hold one shortcut, speak naturally, and insert polished text."
- "Let me dictate without worrying about a quota, subscription, or internet connection."
- "Understand spoken punctuation and simple editing commands."
- "Correct my recurring product names and expand phrases I use often."
- "Show me clearly when the app is listening, transcribing, finished, or needs attention."

### 6.3 Representative scenarios

1. Compose a Slack message and omit the final period for a short conversational tone.
2. Dictate a multi-sentence prompt into a browser or desktop AI application.
3. Say "new paragraph" or "question mark" and receive the corresponding formatting.
4. Correct a phrase by saying "scratch that" and continuing with the replacement thought.
5. Say a configured snippet trigger such as "my address" and insert a longer expansion.
6. Finish with "press enter" to insert and submit the result.
7. Disable automatic insertion but still receive the processed text on the clipboard.

## 7. Supported environment

### 7.1 Baseline compatibility

| Area | Requirement |
|---|---|
| Operating system | macOS 14.0 or newer |
| Verified operating system | macOS 14.6, build 23G80 |
| Verified CPU | Apple Silicon arm64 |
| Verified compiler | Apple Swift 5.10 |
| UI framework | AppKit/Cocoa |
| Audio framework | AVFoundation/AVFAudio |
| Accessibility and events | ApplicationServices, Accessibility API, Core Graphics |
| Runtime architecture | Current bundled `whisper-cli` is arm64 |
| Network | Required only during first engine/model setup |
| Minimum deployment flag | `-mmacosx-version-min=14.0` |

### 7.2 Portability note

The current product is macOS-specific. Rebuilding it on another Apple Silicon Mac is a direct application of this PRD. An Intel Mac would require recompiling both the app and `whisper.cpp` for x86_64 and is not part of the verified baseline. A Windows implementation would require different APIs for global keyboard hooks, audio capture, UI, permissions, clipboard insertion, and application context; it should be treated as a separate platform project that shares the product behavior and text-processing test suite.

## 8. User experience specification

### 8.1 Application lifecycle

1. Launching Echoflow creates the app delegate, initializes local storage, initializes the recorder, builds the HUD, builds the menu-bar menu, builds the settings window, requests/checks Accessibility, and opens the settings window.
2. Closing the settings window does not quit the app.
3. The app remains represented by both a normal Dock presence and a menu-bar status item because `LSUIElement` is false and the activation policy is regular.
4. Reopening the app or clicking its Dock icon brings the settings window forward.
5. Selecting **Quit Echoflow** or Command-Q stops the recorder, invalidates the permission timer, removes the event tap, and terminates the process.

### 8.2 First-launch permission journey

The product requires two independent macOS permissions:

1. **Microphone**
  - Requested when the first dictation starts, not merely at launch.
  - Required to capture speech.
  - Usage description: "Echoflow records speech only while you hold the dictation shortcut and transcribes it locally."

2. **Accessibility**
  - Requested/checked at launch with `AXIsProcessTrustedWithOptions` and the system prompt option enabled.
  - Required for the precise Option + Space event tap.
  - Required for direct selected-text insertion and synthetic Command-V/Return events.
  - Rechecked every 1.5 seconds while the application is open.
  - When permission becomes available, Echoflow starts the shortcut automatically and displays **Echoflow is ready / Hold ⌥ Space to dictate** for 2.5 seconds.
  - When permission is revoked, Echoflow removes its event tap.

macOS must remain the sole authority that grants these permissions. Echoflow MUST NOT attempt to modify the TCC database or bypass the system permission flow.

### 8.3 Primary dictation journey

1. The user places the cursor in a target application.
2. The user presses and holds Option + Space.
3. Echoflow consumes that key combination, verifies it is idle, verifies the local runtime, captures the current frontmost application's name and bundle identifier, and checks microphone permission.
4. Echoflow begins recording a UUID-named WAV file and shows the listening HUD.
5. The waveform reacts to microphone level while the user speaks.
6. The user releases Space or Option + Space.
7. Echoflow stops recording, changes to transcribing state, and shows a spinner with a local-processing message.
8. A background task runs `whisper-cli` and reads the generated transcript file.
9. The text processor applies deterministic cleanup, voice commands, replacements, formatting, and application-specific output rules.
10. The processed text is always placed on the clipboard.
11. If automatic paste is enabled and Accessibility is trusted, Echoflow attempts direct Accessibility insertion at the currently focused element.
12. If direct insertion is not supported, Echoflow posts Command-V after 60 milliseconds.
13. If the user ended with "press enter," Echoflow posts Return after insertion.
14. Echoflow writes history, applies the audio-retention rule, displays a success result for 2.2 seconds, and returns to idle.

### 8.4 Global shortcut requirements

The only baseline shortcut is **hold Option + Space to record; release to stop**.

The implementation MUST use a Core Graphics session event tap at the head of the event stream. It MUST NOT use Carbon `RegisterEventHotKey` for the Space key because that earlier approach could interfere with ordinary Space input.

Constants and configuration:

- Space virtual key code: `49`.
- Event tap location: `kCGSessionEventTap`.
- Placement: `kCGHeadInsertEventTap`.
- Option: `kCGEventTapOptionDefault`, allowing matching events to be suppressed.
- Event mask: key-down and key-up.
- Required modifier flag: `kCGEventFlagMaskAlternate`.
- Run-loop placement: main run loop, common modes.

#### 8.4.1 Event behavior matrix

| Event | Option down | Internal `shortcutDown` | Required behavior | Consume event? |
|---|---:|---:|---|---:|
| Non-Space key down/up | Either | Either | Do nothing | No |
| Space key down | No | No | Pass ordinary Space to focused app | No |
| Space key up | No | No | Pass ordinary Space release | No |
| Space key down | Yes | No | Set `shortcutDown`, request start dictation | Yes |
| Repeated Space key down | Yes | Yes | Do not start twice | Yes |
| Space key up | Either | Yes | Clear `shortcutDown`, request stop dictation | Yes |
| Space key down after abnormal Option release | No | Yes | Clear stale state, stop dictation, pass Space through | No |
| Event tap disabled by timeout/user input | N/A | Either | Re-enable event tap | No |

Ordinary Space preservation is a release-blocking acceptance criterion. A rebuild is not acceptable if Space fails in TextEdit, browsers, messaging apps, password fields, Spotlight, or the Echoflow settings editor while Echoflow is running.

### 8.5 Menu-bar interface

The status item uses the SF Symbol `waveform.circle.fill` with accessibility description **Echoflow**.

The menu contains these items in this order:

1. **Start Dictation** / **Stop Dictation** / **Transcribing…** depending on state.
2. Disabled informational row: **Hold ⌥ Space to dictate**.
3. **Copy Last Transcript**.
4. Separator.
5. **Open Echoflow…**, with Command-comma equivalent.
6. **Refresh Permissions**.
7. Separator.
8. **Quit Echoflow**, with Command-Q equivalent.

The **Start Dictation** / **Stop Dictation** menu item is also a fallback interaction. It can start and stop microphone capture without the Accessibility-backed global shortcut. Without Accessibility, the resulting text remains clipboard-only even when `autoPaste` is enabled.

State presentation:

| State | Toggle title | Toggle enabled | Status tint |
|---|---|---:|---|
| Idle | Start Dictation | Yes | Default |
| Recording | Stop Dictation | Yes | System red |
| Transcribing | Transcribing… | No | System orange |

### 8.6 Settings window

The settings UI is built programmatically with AppKit; there is no storyboard, XIB, SwiftUI view, or web frontend.

Window requirements:

- Content size: 720 × 590 points.
- Style: titled, closable, miniaturizable.
- Initial title: **Echoflow Settings**.
- Center on creation.
- Bring forward and activate the app whenever shown.

Visible content from top to bottom:

1. Product heading **Echoflow**, bold 24 pt.
2. Instruction text: **Hold ⌥ Space, speak, then release · Accessibility enables automatic paste**, 13 pt.
3. Four checkboxes arranged as a two-column grid:
  - Remove filler words → `removeFillers`
  - Smart punctuation and voice commands → `smartFormatting`
  - Paste into the active app → `autoPaste`
  - Keep source audio → `retainAudio`
4. Language selector with these labels/codes in exact order:

  | Label | Stored code |
  |---|---|
  | English | `en` |
  | Auto-detect | `auto` |
  | Hindi | `hi` |
  | Spanish | `es` |
  | French | `fr` |
  | German | `de` |

5. Read-only local model label displaying the selected runtime model filename or **Not installed**.
6. **Dictionary and snippets** heading.
7. Help text: **Edit the JSON below. Triggers and replacements are case-insensitive.**
8. A bordered, vertically scrollable monospaced JSON editor containing only the `dictionary` and `snippets` collections.
9. **Copy Last Transcript** button.
10. **Save Settings** default button with Return equivalent.

Checkbox and language changes save immediately. Dictionary/snippet edits save only when **Save Settings** is clicked.

Every time the settings window is opened, the JSON editor is regenerated from currently persisted in-memory settings. Unsaved JSON editor changes are therefore discarded when the window is reopened.

The JSON editor validator MUST require:

- a top-level JSON object;
- a `dictionary` value that is an array; and
- a `snippets` value that is an array.

On invalid input, show a sheet titled **Dictionary JSON is not valid** and use the JSON parser error or **Keep both dictionary and snippets as JSON arrays.** as explanatory text. On save, temporarily change the window title to **Echoflow Settings — Saved** for one second.

### 8.7 Floating HUD

The HUD is a borderless, non-activating `NSPanel` that never steals focus from the user's target app.

Geometry and presentation:

- Size: 420 × 120 points.
- Position: horizontally centered on the main screen's visible frame, 72 points above its bottom edge.
- Window level: floating.
- Background: transparent outer panel.
- Inner background: active `NSVisualEffectView` using HUD Window material and behind-window blending.
- Corner radius: 22 points.
- Shadow: enabled.
- Mouse interaction: ignored.
- Space behavior: joins all Spaces, appears over full-screen apps, and is transient.
- Icon: SF Symbol `waveform`, system blue.
- Title: bold 17 pt.
- Detail: 12 pt, secondary label color.
- Progress: 18 × 18 spinning indicator at the upper-right.
- Live waveform: 372 × 28 points near the bottom.

HUD states and required copy:

| Situation | Title | Detail | Spinner | Waveform |
|---|---|---|---:|---:|
| Recording | Listening… | Release ⌥ Space to transcribe and insert | Off | Visible/live |
| Transcribing | Transcribing locally… | Audio never leaves this Mac | On | Hidden |
| Successful automatic insertion | Inserted at cursor | Processed transcript | Off | Hidden |
| Clipboard-only result | Copied to clipboard | Enable Accessibility for automatic paste | Off | Hidden |
| Permission newly granted | Echoflow is ready | Hold ⌥ Space to dictate | Off | Hidden |
| Missing runtime at launch | Engine setup needed | Run scripts/setup-engine.sh | Off | Hidden |
| Error | Echoflow needs attention | Error-specific text | Off | Hidden |

Success hides after 2.2 seconds, permission-ready status after 2.5 seconds, missing-runtime status after 4 seconds, and errors after 5 seconds.

### 8.8 Waveform rendering

The listening waveform is deterministic and rendered by a custom `NSView`.

- Keep 38 level samples.
- Clamp every new level to `[0, 1]`.
- Smooth using `smoothed = previous × 0.68 + new × 0.32`.
- Drop the oldest sample whenever the array reaches 38, then append the newest.
- Draw vertical rounded bars centered vertically.
- Gap: 3 points.
- Minimum computed bar width: 2.4 points.
- Minimum bar height: 3 points.
- Apply a sine envelope: `0.62 + 0.38 × sin(progress × π)`.
- Interpolate bar color from sRGB `(0.28, 0.64, 1.0, 1.0)` to `(0.67, 0.38, 1.0, 1.0)` from left to right.
- Reset all 38 samples and the smoothed level to zero when a recording starts.

### 9.1 Application initialization

- **FR-INIT-001:** The app MUST set a regular application activation policy.
- **FR-INIT-002:** The app MUST begin in the idle state.
- **FR-INIT-003:** The app MUST prepare settings, history, and recording storage before accepting dictation.
- **FR-INIT-004:** The app MUST initialize the audio recorder and connect recorder levels to the HUD waveform on the main queue.
- **FR-INIT-005:** The app MUST build both the menu/status interface and settings window on launch.
- **FR-INIT-006:** The app MUST prompt/check Accessibility on launch.
- **FR-INIT-007:** The app MUST show a discoverable settings window on every application launch.
- **FR-INIT-008:** The app MUST surface a missing runtime with the engine-setup HUD.

### 9.2 Dictation state management

Echoflow has exactly three logical states:

| State | Meaning | Allowed primary transition |
|---|---|---|
| `LFStateIdle` | Ready; no capture or transcription in progress | Start → Recording |
| `LFStateRecording` | Microphone capture active | Stop → Transcribing |
| `LFStateTranscribing` | Whisper task/formatting/insertion in progress | Completion/error → Idle |

Requirements:

- **FR-STATE-001:** Start requests MUST be ignored unless the state is idle.
- **FR-STATE-002:** Stop requests MUST be ignored unless the state is recording and a current audio URL exists.
- **FR-STATE-003:** The menu item MUST be disabled while transcribing.
- **FR-STATE-004:** A completion or error path MUST return the app to idle through a common state reset.
- **FR-STATE-005:** The current audio URL MUST be cleared when returning to idle.
- **FR-STATE-006:** The app MUST NOT begin a second recording while one is active or while transcription is running.

### 9.3 Context capture

- **FR-CTX-001:** Immediately before the microphone permission/capture flow, record the frontmost application's bundle identifier and localized name.
- **FR-CTX-002:** Use empty string if the bundle identifier is absent.
- **FR-CTX-003:** Use **Unknown app** if the localized application name is absent.
- **FR-CTX-004:** Use the captured bundle identifier for formatting style and the captured application name for history.
- **FR-CTX-005:** Actual insertion targets the focused element at insertion time, which may differ from the application captured at recording start.

### 9.4 Microphone authorization

- **FR-MIC-001:** Query `AVCaptureDevice` authorization for `AVMediaTypeAudio` when starting.
- **FR-MIC-002:** If undetermined, request permission asynchronously and continue recording on the main queue only when granted.
- **FR-MIC-003:** If denied/restricted, show **Enable Echoflow in Privacy & Security → Microphone.**
- **FR-MIC-004:** Do not record in a denied state.

### 9.5 Audio capture

- **FR-AUDIO-001:** Use `AVAudioEngine` and its input node.
- **FR-AUDIO-002:** Read the device's output format for bus 0 as the source format.
- **FR-AUDIO-003:** Convert to signed 16-bit PCM, 16,000 Hz, mono, non-interleaved audio.
- **FR-AUDIO-004:** Install an input tap on bus 0 with a 2,048-frame buffer.
- **FR-AUDIO-005:** Allocate conversion output capacity as `ceil(inputFrames × 16000/sourceRate) + 32`.
- **FR-AUDIO-006:** Write successfully converted non-empty buffers to an `AVAudioFile` WAV destination.
- **FR-AUDIO-007:** Name files `dictation-<UUID>.wav` in the Recordings directory.
- **FR-AUDIO-008:** Track duration from the recording start date.
- **FR-AUDIO-009:** On stop, remove the tap, stop the engine, release file/converter references, clear start time, and send a zero level.
- **FR-AUDIO-010:** A recording shorter than 0.25 seconds MUST be deleted and ignored without transcription or history.

### 9.6 Audio-level calculation

For each source buffer with float channel data:

1. Calculate root-mean-square amplitude of channel 0.
2. Clamp the log input to at least `0.00001`.
3. Convert to dB with `20 × log10(rms)`.
4. Normalize using `(dB + 55) / 55`.
5. Clamp to `[0, 1]`.
6. Deliver the value to the HUD level handler.

### 9.7 Runtime discovery

The runtime resolver MUST inspect roots in this order:

1. `<main bundle resources>/Runtime`
2. `<current working directory>/Runtime`
3. `<compile-time project source root>/Runtime`, derived by walking up from `__FILE__`

Within a candidate root:

- `whisper-cli` MUST exist and be executable.
- The resolver MUST select the first model present in this exact priority:
 1. `ggml-small.en.bin`
 2. `ggml-base.en.bin`
 3. `ggml-small.bin`
 4. `ggml-base.bin`

The resolver returns the first valid executable/model pair. The installed bundle path should win in a normal packaged launch.

### 9.8 Whisper invocation

For an audio file `/path/input.wav`, Echoflow creates an output prefix by replacing `.wav` with `.transcript`. The expected transcript file is `<prefix>.txt`. A stale output file at that location is deleted before launching Whisper.

The command contract is:

```text
whisper-cli \
 -ng \
 -m <model-path> \
 -f <audio-path> \
 -otxt \
 -of <output-prefix-without-extension> \
 -nt \
 -np \
 -sns \
 [-l <language-code>] \
 --prompt <prompt-terms>
```

Flag meanings in the pinned CLI:

| Flag | Meaning |
|---|---|
| `-ng` | Disable GPU and use the reliable CPU/Accelerate path |
| `-m` | Model file path |
| `-f` | Input WAV file |
| `-otxt` | Write output to a text file |
| `-of` | Output path prefix without extension |
| `-nt` | Omit timestamps |
| `-np` | Suppress normal console printing |
| `-sns` | Suppress non-speech tokens |
| `-l` | Spoken language code; omitted when app setting is `auto` |
| `--prompt` | Initial vocabulary/context prompt |

The built-in prompt terms are:

- `Echoflow`
- `Option + Space`
- `Command-V`

Append each non-empty dictionary replacement value to an ordered set of prompt terms. Join terms with `. ` and pass the result to `--prompt`.

The task's standard output and standard error are directed to the null device. Wait synchronously for the task inside a user-initiated background queue. Exit status zero is required. Read the UTF-8 transcript, delete its `.txt` file after a successful read, trim surrounding whitespace/newlines, and return the resulting string.

### 9.9 Local text processing

Text processing MUST be deterministic and must not perform network calls. The input contract is:

```text
processText(rawTranscript, capturedSettings, capturedApplicationContext)
   -> { text: String, pressEnter: Boolean }
```

The exact ordered pipeline is specified in Section 10. Ordering is part of the compatibility contract because later rules depend on earlier transformations.

### 9.10 Clipboard and insertion

- **FR-INSERT-001:** Always clear the general pasteboard and put the processed text on it before considering automatic insertion.
- **FR-INSERT-002:** If `autoPaste` is false, return clipboard-only status and do not synthesize keys.
- **FR-INSERT-003:** If Accessibility is not trusted, return clipboard-only status and do not synthesize keys.
- **FR-INSERT-004:** First attempt direct insertion through the focused Accessibility element's `kAXSelectedTextAttribute`.
- **FR-INSERT-005:** Check whether `kAXSelectedTextAttribute` is settable before setting it.
- **FR-INSERT-006:** If direct insertion succeeds, report automatic insertion success.
- **FR-INSERT-007:** If direct insertion fails, post Command-V after 60 milliseconds and report automatic insertion success without attempting to verify the receiving application.
- **FR-INSERT-008:** Command-V uses virtual key code `9` with `kCGEventFlagMaskCommand`.
- **FR-INSERT-009:** Return uses virtual key code `36` with no modifier.
- **FR-INSERT-010:** For direct insertion plus `pressEnter`, post Return after 100 milliseconds.
- **FR-INSERT-011:** For Command-V fallback plus `pressEnter`, post Return 160 milliseconds after posting Command-V.
- **FR-INSERT-012:** Create key-down and key-up events from a HID-system-state `CGEventSource` and post them at `kCGHIDEventTap`.

### 9.11 Transcript history

- **FR-HIST-001:** Add successful transcripts to the front of history.
- **FR-HIST-002:** Keep at most 500 entries by removing entries from the end.
- **FR-HIST-003:** Save history as pretty-printed, atomic JSON after every insertion.
- **FR-HIST-004:** Record failed Whisper transcriptions as history entries whose `rawText` is empty and whose `finalText` begins with `Transcription failed: `.
- **FR-HIST-005:** `Copy Last Transcript` uses the in-memory latest transcript when present; otherwise it reads the first history entry's final text.
- **FR-HIST-006:** The current baseline has no history browsing or deletion UI.

### 9.12 Recording retention

The baseline file-retention behavior is:

| Outcome | Audio behavior | History behavior |
|---|---|---|
| Duration under 0.25 seconds | Delete immediately | No entry |
| Successful transcript, `retainAudio=false` | Delete after history save | Entry without `audioPath` |
| Successful transcript, `retainAudio=true` | Keep | Entry with `audioPath` |
| Whisper launch/exit/read failure | Keep | Failure entry with `audioPath` |
| Transcript becomes empty/no speech | Current baseline leaves audio in Recordings | No entry |
| App terminated during recording/transcription | Best effort only; orphaned file may remain | Not guaranteed |

The no-speech/orphan behavior is documented for exact compatibility but is a known cleanup limitation, not an ideal long-term requirement.

## 10. Exact text-processing specification

### 10.1 Processing order

Apply transformations in this exact order:

1. Remove known non-speech annotations.
2. Trim leading/trailing whitespace and newlines.
3. Apply backtrack commands.
4. Detect and remove a trailing "press enter" command.
5. If smart formatting is on, replace spoken punctuation/newline commands and optionally transform an ordinal list.
6. If filler removal is on, remove configured filler expressions.
7. Apply user dictionary entries in priority/length order.
8. Apply user snippets in descending trigger-length order.
9. Apply built-in common corrections.
10. Normalize whitespace and punctuation.
11. If smart formatting is on and text is non-empty:
   1. split selected run-on sentences;
   2. normalize;
   3. infer selected commas;
   4. normalize;
   5. add terminal punctuation;
   6. capitalize sentences;
   7. normalize again.
12. Apply messaging-app final-period behavior.
13. Return text and the `pressEnter` boolean.

### 10.2 Case sensitivity and Unicode

- Regular-expression replacements are case-insensitive unless otherwise noted.
- Phrase boundaries use Unicode letters and numbers, not only ASCII word boundaries.
- Dictionary and snippet matches are whole phrases and must not replace a substring inside a longer alphanumeric word.
- Capitalization uses Unicode lowercase/letter character sets.

### 10.3 Non-speech annotations

Remove bracketed forms of:

- `blank_audio`
- `silence`
- `music playing`
- `applause`
- `laughter`
- `inaudible`

Remove parenthesized forms of:

- `muffled speaking`
- `speaking in foreign language`
- `music playing`
- `inaudible`
- `silence`

The bracketed rule may consume additional characters until `]`, allowing variants such as annotation details.

### 10.4 Backtrack commands

Recognized phrases:

- `scratch that`
- `forget that`
- `start over`

For each trigger, find its last case-insensitive occurrence and keep only the content after it. Trim leading whitespace, newline, comma, period, semicolon, colon, and hyphen characters from what remains.

Example:

```text
Send it on Tuesday. Scratch that, send it on Thursday.
→ Send it on Thursday.
```

### 10.5 Press Enter command

If the transcript ends with the whole phrase `press enter`, optionally followed by `.`, `!`, or `?`, remove that phrase and set `pressEnter=true`. This is an action command only at the end of a dictation. Elsewhere, the phrase remains normal text.

The action is executed only when automatic insertion is enabled and Accessibility is trusted. Clipboard-only operation does not synthesize Return.

### 10.6 Spoken formatting commands

These replacements run only when `smartFormatting=true`:

| Spoken phrase | Output |
|---|---|
| `new paragraph` | Two newline characters |
| `new line` | One newline |
| `next line` | One newline |
| `line break` | One newline |
| `full stop` | `.` |
| `question mark` | `?` |
| `exclamation mark` | `!` |
| `exclamation point` | `!` |
| `comma` | `,` |
| `colon` | `:` |
| `semicolon` | `;` |
| `open quote` | `"` |
| `close quote` | `"` |

### 10.7 Simple ordinal list conversion

Only attempt list conversion if the text contains both `first` and `second`, case-insensitively. Replace these markers, working from fifth backward to first:

- `first` → newline + `1. `
- `second` → newline + `2. `
- `third` → newline + `3. `
- `fourth` → newline + `4. `
- `fifth` → newline + `5. `

Permit an optional comma, colon, and following whitespace after the marker. Trim the resulting outer whitespace/newlines.

### 10.8 Filler removal

When `removeFillers=true`, remove whole occurrences of:

- `um` with repeated `m`
- `uh` with repeated `h`
- `erm` with repeated `m`
- `you know`
- `i mean`
- `kind of`
- `sort of`
- `basically`

Also remove an immediately following optional comma and horizontal whitespace. Do not match inside a larger Unicode word.

### 10.9 Dictionary replacement

Each dictionary item has:

```json
{
 "spoken": "whisper flow",
 "replacement": "Echoflow",
 "priority": false
}
```

Sort rules:

1. Entries with `priority=true` run before entries with `priority=false`.
2. Within the same priority, longer `spoken` values run before shorter values.
3. Apply case-insensitive whole-phrase replacement.

Replacement values also contribute to the Whisper initial prompt when non-empty.

### 10.10 Snippet expansion

Each snippet has:

```json
{
 "trigger": "my email",
 "expansion": "your.email@example.com"
}
```

Sort snippets by descending trigger length, then apply case-insensitive whole-phrase replacement. Snippets run after dictionary entries and before built-in corrections.

### 10.11 Built-in common corrections

Apply these corrections in the listed order:

| Input pattern | Replacement |
|---|---|
| whole phrase `option plus space` | `Option + Space` |
| whole `control-v`, `control v`, or `controlv` | `Command-V` |
| whole phrase `local flow` | `Echoflow` |
| `this changes/things/settings/files/options/features/permissions/questions` | `these <noun>` |
| `these is` | `these are` |
| `these was` | `these were` |
| `more better` | `better` |
| `stuffs` | `things` |

### 10.12 Normalization

Normalization performs all of the following:

- Collapse horizontal spaces/tabs to one space.
- Remove spaces immediately around each newline.
- Collapse three or more newlines to two.
- Remove whitespace before `, . ; : ! ?`.
- Insert a space after `; : ! ?` when followed immediately by a Unicode letter or number.
- Insert a space after `.` or `,` when followed by a letter/number, except when the punctuation is preceded by a number. This preserves decimal strings such as `3.7`.
- Remove whitespace immediately after `(`.
- Remove whitespace immediately before `)`.
- Collapse repeated commas to one comma.
- Collapse repeated exclamation marks to one.
- Collapse repeated question marks to one.
- Trim outer whitespace/newlines.

### 10.13 Word counting

Count sequences of Unicode letters/numbers and permit one apostrophe-delimited letter suffix, supporting forms such as `don't`. Word count controls run-on splitting thresholds.

### 10.14 Question inference

To determine whether a segment is likely a question:

1. Trim and lowercase it.
2. Remove an initial discourse word `also`, `so`, `then`, `well`, or `please` plus comma/space.
3. Return true when the remaining text begins with one of:
  - `who`, `what`, `when`, `where`, `why`, `how`, `which`, `whose`, `whom`
  - `can`, `could`, `would`, `will`, `shall`, `should`
  - `do`, `does`, `did`
  - `is`, `are`, `am`, `was`, `were`
  - `have`, `has`, `had`
  - `may`, `might`, `must`

### 10.15 Run-on sentence splitting

Do not split when:

- total word count is under 14; or
- the input already contains `.`, `!`, or `?` anywhere.

Otherwise, identify candidate boundaries beginning with expressions such as:

- `also`, `however`, `but rather`
- `I want`, `I need`, `I feel`, `I think`, `I don't`
- `we need`, `we should`, `it should`
- `can/could/would/will you`
- `do you`, `does it`, `did you`
- question-word plus auxiliary forms such as `what is`, `why did`, `how can`, `where should`, `when will`
- `another thing`, `the next thing`
- `please remove/keep/delete`
- `remove`, `keep`, `delete`

A candidate is accepted only if:

- it is not at the beginning;
- the portion since the last accepted boundary has at least five words; and
- the remaining portion has at least three words.

Insert `? ` when the preceding portion is a likely question; otherwise insert `. `. Insert boundaries from the end of the string backward so indices remain stable.

### 10.16 Inferred commas

When smart formatting is on:

1. Insert a comma after these sentence/line-initial discourse words when missing:
  - `however`, `therefore`, `additionally`, `also`, `meanwhile`, `instead`, `finally`
  - `first`, `second`, `third`
  - `yes`, `no`, `well`
  - `for example`, `in fact`, `by the way`
2. Insert a comma before `but` or `yet` when followed by a pronoun/demonstrative subject from the implemented list.
3. Convert ` and then ` to `, then `.
4. Insert a comma before `so` when followed by a subject from the implemented list.

### 10.17 Terminal punctuation

Process each line independently:

- Preserve blank lines.
- If a non-empty line does not end with `. , ! ? : ; "`, add punctuation.
- Examine the text after the last existing `.`, `!`, or `?` when deciding the ending.
- Add `?` for a likely question and `.` otherwise.

### 10.18 Sentence capitalization

- Capitalize the first lowercase Unicode letter in the whole text.
- Capitalize the first lowercase letter after a newline.
- Capitalize after `.`, `!`, or `?` only when punctuation is followed by whitespace/newline or is the final character.
- Treat encountering any letter or digit as ending the pending-capitalization state.

### 10.19 Messaging application style

Recognized bundle identifiers:

- `com.apple.MobileSMS`
- `com.tinyspeck.slackmacgap`
- `net.whatsapp.WhatsApp`
- `com.hnc.Discord`
- `ru.keepcoder.Telegram`
- `org.whispersystems.signal-desktop`
- `com.microsoft.teams2`
- `com.microsoft.teams`

Count sentence terminators by splitting on `.`, `!`, and `?`. If the result has no more than two terminated sentences and ends in `.`, remove only the final period. Do not remove `?` or `!`.

## 11. Persistence and data contracts

### 11.1 Application Support paths

All user data is stored under:

```text
~/Library/Application Support/Echoflow/
├── settings.json
├── history.json
└── Recordings/
   └── dictation-<UUID>.wav
```

The directory and Recordings subdirectory are created with intermediate directories enabled.

### 11.2 Settings defaults and schema

Default settings:

```json
{
 "language": "en",
 "removeFillers": true,
 "smartFormatting": true,
 "autoPaste": true,
 "retainAudio": false,
 "dictionary": [
   {
     "spoken": "whisper flow",
     "replacement": "Echoflow",
     "priority": false
   },
   {
     "spoken": "API",
     "replacement": "API",
     "priority": true
   }
 ],
 "snippets": [
   {
     "trigger": "my email",
     "expansion": "your.email@example.com"
   },
   {
     "trigger": "organize my thoughts",
     "expansion": "Please organize the following thoughts into a concise, structured response:"
   }
 ]
}
```

Type contract:

| Key | Type | Allowed/meaning |
|---|---|---|
| `language` | String | `en`, `auto`, `hi`, `es`, `fr`, `de` from UI |
| `removeFillers` | Boolean | Enable filler regex |
| `smartFormatting` | Boolean | Enable voice formatting and advanced punctuation |
| `autoPaste` | Boolean | Attempt insertion instead of clipboard-only |
| `retainAudio` | Boolean | Keep successful source WAV files |
| `dictionary` | Array<object> | `spoken`, `replacement`, optional Boolean `priority` |
| `snippets` | Array<object> | `trigger`, `expansion` |

Loading behavior:

1. Initialize the complete default dictionary.
2. If `settings.json` parses as an object, shallow-merge its top-level keys over defaults.
3. Save the resulting settings immediately as pretty-printed, sorted-key, atomic JSON. This creates the settings file on first launch and fills defaults not present in an older file.

### 11.3 History schema

Example successful entry:

```json
{
 "id": "D7F57E68-6EB6-4B8E-B264-87886345CC7A",
 "createdAt": 1787200000.125,
 "rawText": "um can you help me with this",
 "finalText": "Can you help me with this?",
 "applicationName": "TextEdit",
 "duration": 3.42,
 "audioPath": "/Users/name/Library/Application Support/Echoflow/Recordings/dictation-UUID.wav"
}
```

`audioPath` is optional and is omitted for a normal successful transcript when audio retention is disabled. `createdAt` is seconds since the Unix epoch. History loads only when the file parses as an array; otherwise the app begins with an empty array. History is written with `NSDataWritingAtomic`.

### 11.4 Clipboard contract

The product overwrites the general pasteboard with every non-empty processed transcript. The current baseline does not preserve or restore the previous clipboard contents. Clipboard content remains available even when insertion is disabled or unavailable.

## 12. Error handling and user-visible recovery

### 12.1 Internal error domains/codes

| Code | Source | Meaning |
|---:|---|---|
| 10 | `Echoflow` | Selected microphone format unsupported |
| 20 | `Echoflow` | Whisper executable or model missing |
| 21 | `Echoflow` | `whisper.cpp` exited unsuccessfully |

Other errors may come directly from AVFoundation, file I/O, or `NSTask` launch.

### 12.2 Error behavior

- Any displayed error uses the common title **Echoflow needs attention**.
- The error detail uses the most specific available localized description.
- Errors remain visible for five seconds.
- The app returns to idle after displaying an error.
- A microphone-denied error directs the user to Privacy & Security → Microphone.
- Missing runtime errors direct the user to `scripts/setup-engine.sh`.
- An empty processed transcript reports **No speech was detected.**
- A nonzero Whisper exit reports **whisper.cpp could not transcribe this recording.**

### 12.3 Permission recovery

- **Refresh Permissions** reissues the Accessibility trusted check with the macOS prompt option.
- The 1.5-second watcher makes a relaunch unnecessary after a user enables Echoflow.
- If the installed app is absent from Accessibility, the user can add `~/Applications/Echoflow.app` with the system **+** button.
- If a stale TCC record must be cleared during development, the developer may run `tccutil reset Accessibility app.echoflow.desktop`, reopen the installed app, and manually grant permission again. Resetting does not grant permission.

## 13. Privacy and security requirements

### 13.1 Privacy guarantees

- **PRIV-001:** The app MUST NOT contain analytics, telemetry, advertising, authentication, or cloud speech endpoints.
- **PRIV-002:** The app MUST NOT make network requests during normal installed use.
- **PRIV-003:** Audio MUST be processed by the bundled local Whisper executable.
- **PRIV-004:** The HUD MUST explicitly state **Audio never leaves this Mac** during transcription.
- **PRIV-005:** Settings, history, and retained recordings MUST stay in the user's Application Support directory.
- **PRIV-006:** Audio MUST be recorded only while a recording state is active.

### 13.2 Security boundaries

- Accessibility access is powerful: it permits reading the focused element and posting keystrokes. The app must use it only for shortcut detection and requested insertion.
- The app must never log microphone audio or the focused element's existing contents.
- Transcripts are intentionally stored locally in history and copied to the system pasteboard; both are privacy surfaces that should be disclosed.
- The current ad-hoc build is intended for personal local installation, not untrusted distribution.
- The baseline app has no App Sandbox entitlement, hardened runtime, Developer ID signature, or notarization.
- macOS TCC, not Echoflow, owns Microphone and Accessibility authorization state.

### 13.3 Supply-chain expectations

- Pin `whisper.cpp` to tag `v1.9.1`.
- Prefer a verified commit hash in a future hardening pass; the current setup script shallow-clones the tag.
- If project-local CMake is needed, download CMake 4.3.3 from the official Kitware GitHub release and verify SHA-256 `5221a13450c7a0219a2a0d1b6c9085eb06489721fafd8488ccebc1584175d2fb` before extraction.
- The current setup script does not independently verify a model checksum after `download-ggml-model.sh`. The known baseline `small.en` model hash is recorded in Section 16.5 and should be checked for a byte-identical reconstruction.

## 14. Non-functional requirements

### 14.1 Reliability

- Ordinary Space MUST work with Echoflow idle, recording, transcribing, visible, hidden, and permission-denied.
- Event-tap timeout/user-input disable notifications MUST trigger re-enablement.
- All UI mutations initiated by audio/background work MUST return to the main queue.
- Recording start/stop MUST be idempotent at the state layer.
- Settings and history writes MUST use the baseline atomic write option.
- A failed engine/model lookup MUST not crash the app.

### 14.2 Performance

- Shortcut key-down SHOULD make the listening HUD visible with no intentional delay.
- Permission changes MUST be detected within one 1.5-second timer interval plus normal main-loop scheduling.
- Audio conversion MUST happen incrementally in the AVAudioEngine tap rather than buffering the entire recording in memory.
- Whisper transcription MUST execute off the main thread at user-initiated QoS.
- UI MUST remain responsive while Whisper runs.
- No fixed transcription-latency SLO is imposed because duration depends on recording length, model size, and hardware.

### 14.3 Resource footprint

- The source project with only the staged runtime is approximately 468 MB.
- The installed app with the default model is approximately 468 MB.
- The model is approximately 465 MB.
- The arm64 `whisper-cli` is approximately 3.1 MB.
- Temporary `.build/`, `dist/`, and `Vendor/` content is not required for normal installed use and may be removed after a successful install, provided `Runtime/` is preserved for future rebuilds.

### 14.4 Accessibility

- Menu icon and waveform icon require meaningful accessibility descriptions.
- Settings controls must use native AppKit semantics.
- The HUD must not steal keyboard focus.
- Status must be communicated in text, not color alone.
- Keyboard behavior must not impair ordinary typing.

### 14.5 Maintainability

- Product logic should remain divided between application orchestration, audio capture, text processing, and waveform rendering.
- Text transformations should remain independently testable using Foundation only.
- Runtime versions and download hashes must be declared in scripts rather than tribal knowledge.
- Generated and large artifacts must stay ignored by version control.

## 15. Technical architecture

### 15.1 Component responsibilities

| Component | Responsibility |
|---|---|
| `main.m` | Create `NSApplication`, instantiate delegate, run event loop |
| `EchoflowAppDelegate` | Lifecycle, storage, UI, state machine, permission watcher, global shortcut, Whisper task, insertion, history |
| `EchoflowAudioRecorder` | AVAudioEngine capture, conversion, WAV writing, duration, live level calculation |
| `EchoflowTextProcessor` | Pure deterministic transcript transformation and action-command extraction |
| `EchoflowWaveformView` | Live smoothed audio visualization |
| `whisper-cli` | Local speech recognition process |
| `ggml-*.bin` | Whisper model weights |

### 15.2 End-to-end control flow

```text
CGEventTap Option+Space key-down
   → EchoflowAppDelegate.startDictation
   → runtime check + frontmost app context + microphone permission
   → EchoflowAudioRecorder.startAtURL
   → AVAudioEngine tap
       → AVAudioConverter (device format → 16 kHz Int16 mono)
       → AVAudioFile WAV writes
       → RMS level → EchoflowWaveformView

CGEventTap matching key-up
   → EchoflowAppDelegate.stopDictation
   → recorder.stop + state=Transcribing
   → background NSTask whisper-cli
   → transcript .txt read
   → EchoflowTextProcessor.processText
   → pasteboard write
   → AX selected-text insertion OR Command-V fallback
   → optional Return
   → history save + audio cleanup
   → HUD result + state=Idle
```

### 15.3 Threading model

- AppKit, window/menu mutation, state transitions, HUD mutation, and key-event callback behavior occur on the main run loop.
- AVAudioEngine invokes its tap block on an audio/render-associated thread. The recorder performs conversion/file writes there and calls its level block.
- The app delegate's level block dispatches waveform changes to the main queue.
- `whisper-cli` launch, wait, and transcript file read occur on a global queue with `QOS_CLASS_USER_INITIATED`.
- Completion returns to the main queue for text insertion, history mutation, file retention decisions, HUD display, and state reset.
- Captured settings are copied at stop time so a settings change during transcription does not alter that in-flight result.

### 15.4 Memory and Core Foundation ownership

- The project builds with Swift.
- Core Foundation event tap/run-loop source references are explicitly released.
- The run-loop source is removed before it is released.
- The event tap is invalidated before release.
- Accessibility system-wide/focused element values are explicitly released.
- CGEvent and CGEventSource objects are explicitly released after posting.
- Weak references are used from recorder/timer/background callbacks to the app delegate to avoid retain cycles.

### 15.5 Framework dependencies

Application binary:

- Cocoa/AppKit
- AVFoundation/AVFAudio
- ApplicationServices/Core Graphics
- Foundation
- Core Foundation
- Swift runtime and `libSystem`

Whisper runtime:

- Accelerate
- Foundation/Core Foundation
- Metal and MetalKit are linked because the engine is built with Metal available
- `libc++`
- `libSystem`

Echoflow passes `-ng`, so inference uses CPU/Accelerate even though the runtime links Metal.

## 16. Repository, runtime, and bundle layout

### 16.1 Source tree

```text
Echoflow/
├── Config/
│   ├── Info.plist
│   └── AppIcon.icns
├── Runtime/
│   ├── whisper-cli
│   └── models/
│       └── ggml-small.en.bin
├── Sources/
│   ├── EchoflowAppDelegate.swift
│   ├── EchoflowAppService.swift
│   ├── EchoflowAudioRecorder.swift
│   ├── EchoflowDictionarySheetController.swift
│   ├── EchoflowHUDController.swift
│   ├── EchoflowSettingsWindowController.swift
│   ├── EchoflowTextProcessor.swift
│   ├── EchoflowWaveformView.swift
│   └── main.swift
├── Tests/
│   └── TextProcessorTests.swift
├── scripts/
│   ├── build-app.sh
│   ├── install-app.sh
│   ├── run-tests.sh
│   └── setup-engine.sh
├── .gitignore
└── echoflow_prd.md
```

Generated directories:

- `.build/`: compiled app/test binaries and Swift module caches.
- `dist/`: assembled app bundle.
- `Vendor/`: downloaded CMake, cloned `whisper.cpp`, and engine build tree.

### 16.2 Ignored content

The `.gitignore` excludes:

- `.build/`
- `.swiftpm/`
- `Vendor/`
- `Runtime/whisper-cli`
- `Runtime/models/*.bin`
- `dist/`
- `*.wav`
- `*.txt`

Because runtime files are ignored, a source-only transfer MUST run `scripts/setup-engine.sh` or separately transfer verified runtime artifacts before building a self-contained app.

### 16.3 Installed app layout

```text
~/Applications/Echoflow.app/
└── Contents/
   ├── Info.plist
   ├── MacOS/
   │   └── Echoflow
   ├── Resources/
   │   └── Runtime/
   │       ├── whisper-cli
   │       └── models/
   │           └── ggml-small.en.bin
   └── _CodeSignature/
       └── CodeResources
```

### 16.4 Bundle metadata

| Key | Value |
|---|---|
| `CFBundleDevelopmentRegion` | `en` |
| `CFBundleDisplayName` | `Echoflow` |
| `CFBundleExecutable` | `Echoflow` |
| `CFBundleIdentifier` | `app.echoflow.desktop` |
| `CFBundleInfoDictionaryVersion` | `6.0` |
| `CFBundleName` | `Echoflow` |
| `CFBundlePackageType` | `APPL` |
| `CFBundleShortVersionString` | `0.2.2` |
| `CFBundleVersion` | `7` |
| `LSMinimumSystemVersion` | `14.0` |
| `LSUIElement` | false |
| `NSHighResolutionCapable` | true |
| `NSMicrophoneUsageDescription` | Baseline text specified in Section 8.2 |

### 16.5 Known baseline artifact fingerprints

These fingerprints identify the verified artifacts on the original Apple Silicon Mac:

| Artifact | SHA-256 | Notes |
|---|---|---|
| `Runtime/whisper-cli` | `70e66e497677fd1001bae2fb0e070ce1af0fb32fd7e4f7a27feab6bacefe20f5` | arm64 Mach-O, about 3.1 MB |
| `Runtime/models/ggml-small.en.bin` | `c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d` | about 465 MB |

A source rebuild of `whisper-cli` may not be byte-identical because compiler/build metadata can differ even when behavior is compatible. The model should be byte-identical when downloaded from the same upstream artifact.

## 17. Build and packaging specification

### 17.1 Prerequisites on a clean Mac

Required:

- macOS 14 or newer.
- Apple Command Line Tools with `xcrun` and `swiftc`.
- `git`, `curl`, `shasum`, and `tar` for first runtime setup.
- Internet access for first CMake, source, and model download.
- Sufficient free disk space for the model, vendor sources, engine build, and app bundle. Several gigabytes are prudent during setup even though the cleaned project and final app are about 468 MB each.

Homebrew, Python, Node.js, Swift Package Manager, Xcode project files, API keys, and a Wispr account are not required.

### 17.2 Engine setup script contract

Invocation:

```bash
./scripts/setup-engine.sh [base.en|small.en|base|small]
```

Default model: `small.en`.

Behavior:

1. Validate model name.
2. Validate `git`, `curl`, `shasum`, and `tar`.
3. Create `Vendor/` and `Runtime/models/`.
4. Use a `cmake` already on PATH when available.
5. Otherwise download project-local CMake 4.3.3 universal from Kitware GitHub, verify the fixed SHA-256, and extract it under `Vendor/`.
6. Shallow-clone `ggml-org/whisper.cpp` tag `v1.9.1` when `Vendor/whisper.cpp/.git` does not exist.
7. Configure Release with:
  - `BUILD_SHARED_LIBS=OFF`
  - `GGML_METAL=ON`
  - `WHISPER_BUILD_TESTS=OFF`
  - `WHISPER_BUILD_EXAMPLES=ON`
8. Build with four parallel jobs.
9. Run upstream `models/download-ggml-model.sh <model>`.
10. Install executable permissions on `Runtime/whisper-cli`.
11. Copy the selected model to `Runtime/models/` with mode 0644.

### 17.3 Application build script contract

The app is compiled directly with `xcrun swiftc`, not with Xcode, SwiftPM, or CMake.

Compiler settings:

```text
-O
-target arm64-apple-macos14.0
-sdk <sdk-path>
-module-cache-path <project>/.build/ModuleCache
-framework Cocoa
-framework AVFoundation
-framework ApplicationServices
-framework Carbon
-framework ServiceManagement
Sources/*.swift
```

Output binary: `.build/release/Echoflow`.

Packaging steps:

1. Recreate only the known path `dist/Echoflow.app`.
2. Create `Contents/MacOS` and `Contents/Resources`.
3. Install the app binary as `Contents/MacOS/Echoflow`, mode 0755.
4. Install `Config/Info.plist` as `Contents/Info.plist`, mode 0644.
5. If `Runtime/whisper-cli` is executable, copy the complete `Runtime/` tree to `Contents/Resources/Runtime` with `ditto`.
6. If the runtime is missing, finish the build with a warning so the UI can present engine setup guidance.
7. Apply a recursive ad-hoc signature with `codesign --force --deep --sign -`.

The current bundle has no custom entitlements, no Team Identifier, and an ad-hoc signature.

### 17.4 Test build contract

`scripts/run-tests.sh` compiles only `EchoflowTextProcessor.m` and `TextProcessorTests.m` with Foundation. It uses ARC, modules, the macOS 14 deployment target, and a dedicated module cache. The resulting `.build/EchoflowSmokeTests` executable must exit zero.

### 17.5 Installation contract

`scripts/install-app.sh`:

1. Builds automatically if `dist/Echoflow.app` is absent.
2. Creates `~/Applications` when needed.
3. Copies the bundle to `~/Applications/Echoflow.app` with `ditto`.
4. Does not install into `/Applications`, because a managed Mac may prohibit that path.

### 17.6 Clean-machine rebuild procedure

From a source checkout/copy:

```bash
cd /path/to/Echoflow
chmod +x scripts/*.sh
./scripts/setup-engine.sh small.en
./scripts/run-tests.sh
./scripts/build-app.sh
./scripts/install-app.sh
open ~/Applications/Echoflow.app
```

Then:

1. Approve Accessibility for the exact installed `~/Applications/Echoflow.app` entry.
2. Start the first dictation and approve Microphone.
3. Wait up to two seconds for the ready HUD after enabling Accessibility.
4. Validate ordinary Space in TextEdit.
5. Validate Option + Space dictation into TextEdit.
6. Validate clipboard-only operation by disabling **Paste into the active app**.

### 17.7 Post-install verification

Recommended checks:

```bash
plutil -p ~/Applications/Echoflow.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 ~/Applications/Echoflow.app
otool -L ~/Applications/Echoflow.app/Contents/MacOS/Echoflow
test -x ~/Applications/Echoflow.app/Contents/Resources/Runtime/whisper-cli
test -f ~/Applications/Echoflow.app/Contents/Resources/Runtime/models/ggml-small.en.bin
```

The application binary must not link Carbon and must link ApplicationServices/CoreGraphics.

### 17.8 Safe build-artifact cleanup

After the installed app and staged `Runtime/` have been verified, these project-local generated paths can be deleted:

```text
.build/
dist/
Vendor/
```

Do not delete `Runtime/` if future local builds should remain possible without redownloading/recompiling the engine. Do not delete `~/Applications/Echoflow.app`; that is the runnable installed application.

## 18. Model and language behavior

### 18.1 Supported setup choices

| Model argument | Model filename | Language type | Relative tradeoff |
|---|---|---|---|
| `base.en` | `ggml-base.en.bin` | English-only | Smaller/faster, lower accuracy |
| `small.en` | `ggml-small.en.bin` | English-only | Default, larger/slower, higher accuracy |
| `base` | `ggml-base.bin` | Multilingual | Smaller multilingual option |
| `small` | `ggml-small.bin` | Multilingual | Larger multilingual option |

### 18.2 Language UI/model compatibility

The UI always offers English, auto-detect, Hindi, Spanish, French, and German. A rebuild MUST preserve this baseline UI. However, non-English recognition requires a multilingual `base` or `small` model for correct behavior. The default `small.en` model is English-only. This mismatch is a documented baseline limitation; a future build should disable incompatible choices or support switching bundled models.

When multiple models exist in one Runtime folder, the resolver prioritizes English `.en` models before multilingual models. Therefore merely adding `ggml-small.bin` beside `ggml-small.en.bin` will not make the multilingual model active.

## 19. Quality assurance plan

### 19.1 Existing automated text test vectors

The rebuild MUST reproduce these test outcomes exactly with the baseline settings unless a deliberately versioned behavior change is approved:

| Test | Input | Expected output/action |
|---|---|---|
| Filler removal and formatting | `Um hello comma you know new paragraph this is whisper flow.` | `Hello,\n\nThis is Echoflow.` |
| Backtrack correction | `Send it on Tuesday. Scratch that, send it on Thursday.` | case-insensitive equality with `send it on thursday.` |
| Press-enter text | `Looks good. Press enter.` | `Looks good.` |
| Press-enter action | same | `pressEnter=true` |
| Snippet expansion | `Ship it to my address.` with snippet | `Ship it to 42 Example Road.` |
| Messaging style | `Sounds good.` in Slack | `Sounds good` |
| Spacing/question inference | `hello ,world!how are you` | `Hello, world! How are you?` |
| Question ending | `can you help me with this` | `Can you help me with this?` |
| Long run-on | baseline long dictation test | `Can we improve this formatting? I want the spaces and commas to be correct. Also, can you paste the result wherever my cursor is?` |
| Conversational filler | `I mean basically can you fix this` | `Can you fix this?` |
| Decimal spacing | `version 3.7 is ready` | `Version 3.7 is ready.` |
| Common grammar | `this changes are more better` | `These changes are better.` |
| Non-speech annotation | `[MUSIC PLAYING]` | empty string |

### 19.2 Shortcut manual test matrix

Test in at least TextEdit, a Chromium browser text field, and one messaging application:

1. Tap Space repeatedly while Echoflow is idle: every space appears.
2. Hold Space: normal key repeat behavior remains available to the target app.
3. Press Option alone: no Echoflow action.
4. Hold Option + Space: one recording starts; key repeat does not start additional recordings.
5. Release Space before Option: recording stops once.
6. Release Option before Space: recording stops and the next ordinary Space works.
7. Press unrelated shortcuts containing Option: Echoflow does nothing.
8. Use Space while Echoflow transcribes: Space reaches the target app.
9. Revoke Accessibility: event tap is removed and ordinary Space remains normal.
10. Grant Accessibility while Echoflow stays open: ready HUD appears within approximately two seconds and shortcut begins working without relaunch.

### 19.3 Audio and transcription tests

- First-use microphone prompt appears and denial gives actionable HUD copy.
- A supported microphone produces a valid 16 kHz mono Int16 WAV.
- Live waveform changes with speech and returns to zero on stop.
- A sub-250 ms capture is deleted and does not run Whisper.
- A normal English recording produces non-empty local text.
- Engine operation succeeds with Wi-Fi disabled after installation.
- Missing executable and missing model both show engine guidance rather than crashing.
- Whisper nonzero exit returns the app to idle and preserves diagnostic history/audio.
- CPU inference uses `-ng`; no Metal allocator crash occurs on the verified macOS 14.6 system.

### 19.4 Formatting tests beyond the current suite

A production hardening pass SHOULD add cases for:

- Each spoken punctuation command.
- One/two newlines and three-newline collapse.
- Decimal and thousands punctuation.
- Parenthesis spacing.
- Unicode names and contractions.
- Each likely-question prefix.
- Every built-in correction.
- Priority dictionary ordering and overlapping phrases.
- Overlapping snippet triggers.
- Empty and malformed dictionary entries.
- Multiple backtrack commands.
- "press enter" in the middle versus at the end.
- Each messaging bundle identifier.
- Smart formatting disabled.
- Filler removal disabled.
- All-noise and whitespace-only transcript output.

### 19.5 Insertion tests

- Direct AX insertion into a native AppKit text field.
- Selected-text replacement rather than unconditional append.
- Command-V fallback into an app that does not expose settable selected text.
- Clipboard-only behavior when auto-paste is disabled.
- Clipboard-only behavior without Accessibility.
- Return after direct insertion.
- Return after paste fallback.
- No Return for clipboard-only results.
- Insertion remains directed to the focused element at completion time.

### 19.6 Persistence tests

- First launch creates valid default settings.
- Partial saved settings merge over defaults.
- Invalid settings JSON does not crash.
- Invalid editor JSON produces a sheet and does not overwrite data.
- Checkbox/language changes save immediately.
- History keeps newest-first order.
- Entry 501 evicts the oldest entry.
- `Copy Last Transcript` works after relaunch using history.
- Retain-audio setting produces the expected optional `audioPath`.

## 20. Baseline acceptance criteria and definition of done

### 20.1 Product acceptance

- **AC-001:** A clean Apple Silicon Mac with macOS 14+ can build the app using the documented scripts.
- **AC-002:** The app installs and launches from `~/Applications/Echoflow.app`.
- **AC-003:** The settings window appears on launch and can be reopened after closing.
- **AC-004:** The menu-bar icon and exact menu actions are present.
- **AC-005:** Microphone and Accessibility permissions are requested through standard macOS APIs.
- **AC-006:** Enabling Accessibility while the app is open activates the shortcut automatically.
- **AC-007:** Holding Option + Space records; releasing it transcribes.
- **AC-008:** Ordinary Space always reaches the focused application.
- **AC-009:** Audio is converted to 16 kHz mono Int16 WAV.
- **AC-010:** Transcription runs through bundled `whisper.cpp` with the specified flags and no cloud service.
- **AC-011:** The deterministic formatting pipeline produces all existing expected test results.
- **AC-012:** Processed text is always copied to the clipboard.
- **AC-013:** With Accessibility and auto-paste, text is inserted into the focused field.
- **AC-014:** If direct AX insertion fails, Command-V fallback is attempted.
- **AC-015:** "Press enter" triggers Return only after automatic insertion.
- **AC-016:** History and settings persist using the documented schemas.
- **AC-017:** Successful audio is deleted or retained according to the setting.
- **AC-018:** The HUD communicates recording, transcription, result, readiness, and errors without taking focus.
- **AC-019:** Closing the settings window does not stop global dictation.
- **AC-020:** The installed app works with network access disabled after setup.

### 20.2 Engineering acceptance

- `scripts/run-tests.sh` exits zero with all 13 current test cases passing.
- `scripts/build-app.sh` exits zero with no compilation errors.
- `codesign --verify --deep --strict` succeeds on the installed bundle.
- The installed app contains its executable, `whisper-cli`, and one supported model.
- The application binary does not link Carbon.
- The application does not contain network/API client code.
- No source build directory is required at runtime.
- All generated large artifacts remain excluded from version control.

## 21. Known limitations and technical debt

These are descriptions of the current baseline, not permission to omit required behavior:

1. **Heuristic grammar only:** formatting is deterministic regex/rule processing and cannot match a large language model's semantic rewriting.
2. **English default versus multilingual UI:** language choices can be incompatible with `small.en`.
3. **Fixed shortcut:** Option + Space is hard-coded and not user-configurable.
4. **No history UI:** history exists only in JSON; UI exposes only copy-last.
5. **Clipboard replacement:** the previous pasteboard content is not restored.
6. **Unverified fallback insertion:** the app considers a posted Command-V successful without confirming the target received text.
7. **Focus can move:** app context is captured at recording start, but insertion uses whatever field is focused at completion.
8. **Shallow settings validation:** dictionary/snippet arrays are required, but individual item types/keys are not deeply validated.
9. **Silent persistence errors:** many settings/history/file-write errors are ignored.
10. **Orphan audio:** no-speech, crash, force-quit, and some error paths can leave WAV files.
11. **No recording limit:** there is no maximum recording duration or storage quota for retained audio.
12. **No task cancellation:** the Whisper process cannot be cancelled from the UI.
13. **Suppressed engine diagnostics:** stdout/stderr go to the null device, limiting troubleshooting.
14. **Personal signing:** ad-hoc signing is unsuitable for broad distribution and may cause permission re-approval after rebuilds.
15. **No app icon asset:** the status bar uses an SF Symbol; the bundle does not define a custom app icon.
16. **No launch-at-login:** the user must open Echoflow manually.
17. **No automatic update mechanism.**
18. **macOS only:** system integrations are not portable as written.
19. **Ultra-short HUD cleanup:** a recording under 0.25 seconds is deleted and returns to idle, but the current code does not explicitly hide the already-presented transcribing HUD on that branch.
20. **Permission revocation during recording:** removing Accessibility tears down the event tap and clears shortcut state, but does not itself call `stopDictation`; the menu item may be needed to stop a recording if permission is revoked while the shortcut is held.
21. **Runtime label refresh:** the model label is created with the settings window and is not dynamically refreshed if Runtime files are installed or changed while the app stays open.

## 22. Recommended AI implementation milestones

An AI rebuilding Echoflow SHOULD implement and validate in this order.

### Milestone 0: Repository and build skeleton

- Create the source tree from Section 16.1.
- Create `Info.plist` with the exact bundle metadata and microphone usage string.
- Create a minimal Swift/AppKit event-loop application.
- Implement build, test, setup, and install scripts.
- Confirm the empty app launches from `~/Applications`.

Exit criteria: signed app bundle launches and shows a native window.

### Milestone 1: Persistence and settings UI

- Implement default settings, merge/load/save behavior, and history load/save.
- Build the settings window, checkboxes, language pop-up, JSON editor, save validation, and copy-last behavior.
- Build the menu-bar status item and app lifecycle semantics.

Exit criteria: preferences persist across relaunch and invalid editor JSON is rejected.

### Milestone 2: Audio capture and HUD

- Implement `EchoflowAudioRecorder` and exact conversion format.
- Implement duration and RMS normalization.
- Build the non-activating visual-effect HUD and custom waveform.
- Implement Idle/Recording/Transcribing UI presentation.

Exit criteria: microphone capture writes a playable 16 kHz mono Int16 WAV and HUD waveform responds.

### Milestone 3: Local engine integration

- Implement the pinned engine setup script.
- Implement runtime search/model priority.
- Implement exact Whisper task arguments, prompt construction, transcript read, and background execution.
- Preserve CPU `-ng` behavior.

Exit criteria: a WAV transcribes locally with Wi-Fi disabled.

### Milestone 4: Deterministic text processor

- Implement the ordered pipeline in Section 10 as a Foundation-only component.
- Add the exact 13 baseline tests.
- Add edge tests where practical.

Exit criteria: all baseline expected strings and action booleans match exactly.

### Milestone 5: Insertion and application context

- Capture frontmost app context.
- Always write clipboard.
- Implement direct AX selected-text insertion.
- Implement Command-V and Return fallbacks/timing.
- Implement history and retention matrix.

Exit criteria: native and fallback text fields both receive output; clipboard-only mode works.

### Milestone 6: Safe global shortcut and permissions

- Implement the precise Core Graphics event tap.
- Implement the exact event behavior matrix.
- Implement Accessibility prompt/check and 1.5-second permission watcher.
- Verify Carbon is not linked or used.

Exit criteria: Option + Space works and all ordinary Space regression cases pass.

### Milestone 7: Full-system validation and cleanup

- Run automated tests.
- Run manual matrices in Section 19.
- Build/install/sign the complete bundle.
- Confirm bundled runtime independence from the source tree.
- Remove `.build`, `dist`, and optional `Vendor` after verification while retaining `Runtime`.

Exit criteria: all Section 20 acceptance criteria pass.

## 23. Troubleshooting guide

### 23.1 Option + Space does not respond

1. Confirm Echoflow is running from `~/Applications/Echoflow.app`.
2. Open System Settings → Privacy & Security → Accessibility.
3. Enable the Echoflow entry for the installed copy.
4. Wait approximately two seconds for **Echoflow is ready**.
5. If multiple development copies share the bundle identifier, remove stale entries and grant the installed copy.
6. Use **Refresh Permissions** to reopen the system prompt.
7. Verify no other application owns Option + Space.

### 23.2 Ordinary Space does not work

1. Confirm the build uses `CGEventTapCreate` and not Carbon `RegisterEventHotKey`.
2. Confirm non-Option Space key-down returns the original event.
3. Confirm stale `shortcutDown` recovery stops dictation but still returns the ordinary Space event.
4. Check for another global hotkey/remapping utility.
5. Quit Echoflow. If Space remains broken, Echoflow is not the active cause.

### 23.3 Dictation starts but text does not insert

1. Confirm **Paste into the active app** is checked.
2. Confirm Accessibility is granted to the exact installed bundle.
3. Check the clipboard; Echoflow always copies processed text even if insertion is unavailable.
4. Test a native AppKit text field and then a browser field to distinguish AX direct insertion from paste fallback.

### 23.4 Microphone cannot start

1. Enable Echoflow under Privacy & Security → Microphone.
2. Confirm an input device is available and has a nonzero sample rate.
3. Relaunch after changing the selected input device if AVAudioEngine remains stale.

### 23.5 Engine setup needed

1. Run `./scripts/setup-engine.sh small.en` from the project root.
2. Confirm `Runtime/whisper-cli` is executable.
3. Confirm a supported model exists under `Runtime/models/`.
4. Rebuild and reinstall so Runtime is copied inside the app bundle.

### 23.6 Whisper fails or crashes on the verified Sonoma machine

- Confirm the app passes `-ng`.
- Do not remove `-ng` merely because the runtime was built with Metal.
- The baseline deliberately uses CPU/Accelerate because the Whisper Metal allocator crashed on the original macOS 14.6 graphics stack.

### 23.7 Build becomes several gigabytes

- `Vendor/whisper.cpp/build`, downloaded CMake, `.build`, and `dist` are generated artifacts.
- After installation, remove `.build`, `dist`, and optionally `Vendor`.
- Preserve `Runtime` to keep future builds possible without engine setup.
- The expected cleaned source/runtime footprint is approximately 468 MB with `small.en`.

## 24. Future product opportunities

Future work must be versioned separately and must retain a regression test for ordinary Space.

Potential improvements:

- Configurable shortcuts with conflict detection.
- Optional local LLM or richer deterministic grammar engine.
- Streaming transcription and partial preview.
- Transcript history/search/edit UI.
- Audio-retention cleanup policy and storage usage UI.
- Restore previous clipboard contents after verified insertion.
- Better insertion success detection and per-application adapters.
- Focus-lock option so output returns to the application captured at recording start.
- Compatible model/language selector with model switching.
- Engine diagnostics visible in a privacy-safe troubleshooting view.
- Launch at login.
- Developer ID signing, hardened runtime, notarization, and update delivery.
- Universal or separately packaged Intel build.
- A separately engineered Windows application sharing the text-processing specification and acceptance suite.
- Deeper unit tests for shortcut state, persistence, audio retention, and runtime resolution.

## 25. Final reconstruction checklist

Before declaring an independent rebuild complete, answer **yes** to every item:

- [ ] Is the product a native macOS application with bundle ID `app.echoflow.desktop`?
- [ ] Does it launch a visible settings window and remain active after the window closes?
- [ ] Is there a waveform menu-bar item with the specified actions?
- [ ] Does Accessibility automatically activate the shortcut after permission is granted?
- [ ] Does only Option + Space get consumed?
- [ ] Does ordinary Space work everywhere while Echoflow runs?
- [ ] Does hold start and release stop exactly once?
- [ ] Does the HUD remain non-activating and show a live 38-sample waveform?
- [ ] Is audio recorded as 16 kHz mono Int16 WAV?
- [ ] Is the bundled Whisper runtime pinned to v1.9.1 and invoked with the specified flags?
- [ ] Does CPU/Accelerate inference work with `-ng`?
- [ ] Does the exact text-processing pipeline run in the exact order?
- [ ] Do all 13 baseline text tests pass?
- [ ] Is text always copied to the clipboard?
- [ ] Does direct AX insertion fall back to Command-V?
- [ ] Does trailing "press enter" submit only after automatic insertion?
- [ ] Do settings and history match the documented JSON schemas?
- [ ] Does history cap at 500 newest-first entries?
- [ ] Does successful audio follow the retain/delete setting?
- [ ] Does the installed bundle include the engine and model?
- [ ] Does the installed app run without the source tree and without internet access?
- [ ] Does signature verification pass?
- [ ] Is Carbon absent from the application binary?
- [ ] Are privacy guarantees and known limitations documented to the user?

---

This PRD describes the complete Echoflow 0.2.2 baseline as implemented on 2026-08-20. Any behavioral change should update the product version, automated expectations, acceptance criteria, and this document together.
