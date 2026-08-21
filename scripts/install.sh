#!/bin/bash
set -e

echo "====================================="
echo "   Installing Echoflow for macOS"
echo "====================================="

# Define variables
REPO="bahumukh/EchoFlow"
APP_NAME="Echoflow"
ZIP_NAME="${APP_NAME}-macOS.zip"
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${ZIP_NAME}"
TMP_DIR="/tmp/echoflow_install"
ZIP_PATH="${TMP_DIR}/${ZIP_NAME}"

# Create temp directory
mkdir -p "$TMP_DIR"

echo "Downloading latest release..."
if ! curl -fsSL "$DOWNLOAD_URL" -o "$ZIP_PATH"; then
    echo "Error: Failed to download Echoflow. Make sure a release exists at $DOWNLOAD_URL"
    exit 1
fi

echo "Extracting ZIP..."
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

echo "Copying to Applications folder (requires administrator privileges)..."
sudo cp -R "${TMP_DIR}/${APP_NAME}.app" "/Applications/"

echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "====================================="
echo "Echoflow installed successfully! 🎉"
echo "You can launch it from your Applications folder."
echo "====================================="
