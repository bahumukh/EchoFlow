# Echoflow for Windows

This directory contains the native Windows implementation of Echoflow, written in C# and WPF (.NET 8.0).

The Windows client provides identical functionality to the macOS client:
- Global low-friction hold-to-talk dictation (Hold `F12` key).
- Seamless text insertion into any active Windows application via simulated `Ctrl+V`.
- Uses the shared `whisper.cpp` engine bundled in the root `Vendor/` and `Runtime/` directories.

## Architecture
- **UI**: WPF (Windows Presentation Foundation) with a custom borderless, semi-transparent HUD.
- **Audio Recording**: `NAudio` (Standard open-source C# audio library).
- **Global Hotkeys**: Win32 `SetWindowsHookEx` (Low-Level Keyboard Hook).
- **Text Insertion**: Win32 `SendInput`.

## Build Instructions

To compile and run this application, you **must be on a Windows machine**.

1. Install the [.NET 8.0 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0).
2. Open a command prompt or PowerShell and navigate to this directory.
3. Restore dependencies (NAudio and Newtonsoft.Json):
   ```cmd
   dotnet restore
   ```
4. Build and run the application:
   ```cmd
   dotnet run
   ```

**Note:** Ensure that the `whisper-cli.exe` and `.bin` models exist in the `../Runtime/` folder relative to the executable before running, otherwise inference will silently fail.
