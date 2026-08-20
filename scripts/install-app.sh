#!/bin/bash
# install-app.sh — Install Echoflow to ~/Applications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_SRC="$PROJECT_ROOT/dist/Echoflow.app"

# Build if not already built
if [ ! -d "$APP_SRC" ]; then
    echo "==> App bundle not found, building first..."
    "$SCRIPT_DIR/build-app.sh"
fi

# Create ~/Applications if needed
mkdir -p "$HOME/Applications"

# Install
INSTALL_DIR="$HOME/Applications/Echoflow.app"
echo "==> Installing to $INSTALL_DIR..."

# Remove old install
rm -rf "$INSTALL_DIR"

# Copy with ditto to preserve metadata
ditto "$APP_SRC" "$INSTALL_DIR"

echo ""
echo "==> Installed successfully!"
echo "    Location: $INSTALL_DIR"
echo "    Launch:   open $INSTALL_DIR"
echo ""
echo "After launch:"
echo "  1. Approve Accessibility in System Settings → Privacy & Security → Accessibility"
echo "  2. Hold Fn key to start your first dictation (will prompt for Microphone)"
