#!/bin/bash
# build-app.sh — Compile Echoflow and package into app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building Echoflow..."

# Create build output directory
mkdir -p "$PROJECT_ROOT/.build/release"

# Compile with swiftc
xcrun swiftc \
    -O \
    -target arm64-apple-macos14.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -module-cache-path "$PROJECT_ROOT/.build/ModuleCache" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework ApplicationServices \
    -framework Carbon \
    -framework ServiceManagement \
    -o "$PROJECT_ROOT/.build/release/Echoflow" \
    "$PROJECT_ROOT/Sources/main.swift" \
    "$PROJECT_ROOT/Sources/EchoflowTextProcessor.swift" \
    "$PROJECT_ROOT/Sources/EchoflowAudioRecorder.swift" \
    "$PROJECT_ROOT/Sources/EchoflowWaveformView.swift" \
    "$PROJECT_ROOT/Sources/EchoflowAppDelegate.swift" \
    "$PROJECT_ROOT/Sources/EchoflowOnboardingController.swift" \
    "$PROJECT_ROOT/Sources/EchoflowModelManager.swift" \
    "$PROJECT_ROOT/Sources/EchoflowSettingsWindowController.swift" \
    "$PROJECT_ROOT/Sources/EchoflowDictionarySheetController.swift" \
    "$PROJECT_ROOT/Sources/EchoflowHistorySheetController.swift" \
    "$PROJECT_ROOT/Sources/EchoflowHUDController.swift" \
    "$PROJECT_ROOT/Sources/EchoflowAppService.swift"

echo "==> Compilation successful"

# Package into app bundle
APP_DIR="$PROJECT_ROOT/dist/Echoflow.app"

# Clean and recreate only the known path
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Install binary
cp "$PROJECT_ROOT/.build/release/Echoflow" "$APP_DIR/Contents/MacOS/Echoflow"
chmod 755 "$APP_DIR/Contents/MacOS/Echoflow"

# Install Info.plist
cp "$PROJECT_ROOT/Config/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod 644 "$APP_DIR/Contents/Info.plist"

# Install AppIcon
if [ -f "$PROJECT_ROOT/Config/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Config/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Install Runtime if available
if [ -x "$PROJECT_ROOT/Runtime/whisper-cli" ]; then
    echo "==> Bundling Runtime..."
    ditto "$PROJECT_ROOT/Runtime" "$APP_DIR/Contents/Resources/Runtime"
else
    echo "WARNING: Runtime/whisper-cli not found or not executable."
    echo "         The app will build but show 'Engine setup needed' at launch."
    echo "         Run ./scripts/setup-engine.sh first."
fi

# Ad-hoc codesign
echo "==> Signing app bundle..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "==> Build complete: $APP_DIR"
echo "    Run: open $APP_DIR"
echo "    Or install: ./scripts/install-app.sh"
