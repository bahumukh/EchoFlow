#!/bin/bash
set -e

echo "====================================="
echo "   Installing Echoflow for macOS"
echo "====================================="

# Define variables
REPO="bahumukh/EchoFlow"
APP_NAME="Echoflow"
DMG_NAME="${APP_NAME}-macOS.dmg"
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${DMG_NAME}"
TMP_DIR="/tmp/echoflow_install"
DMG_PATH="${TMP_DIR}/${DMG_NAME}"

# Create temp directory
mkdir -p "$TMP_DIR"

echo "Downloading latest release..."
if ! curl -fsSL "$DOWNLOAD_URL" -o "$DMG_PATH"; then
    echo "Error: Failed to download Echoflow. Make sure a release exists at $DOWNLOAD_URL"
    exit 1
fi

echo "Mounting DMG..."
hdiutil attach "$DMG_PATH" -nobrowse -quiet

echo "Copying to Applications folder (requires administrator privileges)..."
sudo cp -R "/Volumes/${APP_NAME}/${APP_NAME}.app" "/Applications/"

echo "Unmounting DMG..."
hdiutil detach "/Volumes/${APP_NAME}" -quiet

echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "====================================="
echo "Echoflow installed successfully! 🎉"
echo "You can launch it from your Applications folder."
echo "====================================="
