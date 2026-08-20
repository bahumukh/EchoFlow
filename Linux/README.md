# Echoflow for Linux

This directory contains the native Linux implementation of Echoflow, written in C++17 and GTK3.

The Linux client provides identical functionality to the macOS client:
- Global low-friction hold-to-talk dictation (Hold `F12` key).
- Seamless text insertion into any active Linux application.
- Uses the shared `whisper.cpp` engine bundled in the root `Vendor/` and `Runtime/` directories.

## Architecture
- **UI**: GTK3 with a custom borderless, semi-transparent Cairo HUD.
- **Audio Recording**: `ALSA` (Advanced Linux Sound Architecture).
- **Global Hotkeys**: `X11` (`XGrabKey`).
- **Text Insertion**: `XTest` (`XTestFakeKeyEvent`).

> **Note on Wayland**: Because Wayland explicitly prevents applications from globally grabbing keys or simulating keystrokes for security reasons, Echoflow relies on X11 APIs. Wayland users may need to run this under XWayland, or manually map compositor shortcuts to trigger it via IPC in the future.

## Build Instructions

To compile and run this application, you **must be on a Linux machine** (e.g., Ubuntu/Debian).

1. Install dependencies:
   ```bash
   sudo apt update
   sudo apt install build-essential cmake libgtk-3-dev libasound2-dev libx11-dev libxtst-dev
   ```
2. Navigate to this directory and run CMake:
   ```bash
   mkdir build && cd build
   cmake ..
   make
   ```
3. Run the application:
   ```bash
   ./echoflow
   ```

**Note:** Ensure that the `whisper-cli` and `.bin` models exist in the `../Runtime/` folder relative to the executable before running, otherwise inference will silently fail.
