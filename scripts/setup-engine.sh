#!/bin/bash
# setup-engine.sh — Download and build whisper.cpp v1.9.1 runtime
# Usage: ./scripts/setup-engine.sh [base.en|small.en|base|small]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODEL_NAME="${1:-small.en}"

# Validate model name
case "$MODEL_NAME" in
    base.en|small.en|base|small) ;;
    *)
        echo "Error: Invalid model name '$MODEL_NAME'"
        echo "Usage: $0 [base.en|small.en|base|small]"
        exit 1
        ;;
esac

MODEL_FILE="ggml-${MODEL_NAME}.bin"

# Validate prerequisites
for cmd in git curl shasum tar; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' not found"
        exit 1
    fi
done

echo "==> Setting up Echoflow engine (model: $MODEL_NAME)"

# Create directories
mkdir -p "$PROJECT_ROOT/Vendor"
mkdir -p "$PROJECT_ROOT/Runtime/models"

# --- CMake ---
CMAKE_BIN=""
if command -v cmake &>/dev/null; then
    CMAKE_BIN="$(command -v cmake)"
    echo "==> Using system CMake: $CMAKE_BIN"
else
    CMAKE_VERSION="4.3.3"
    CMAKE_TAR="cmake-${CMAKE_VERSION}-macos-universal.tar.gz"
    CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_TAR}"
    CMAKE_SHA256="5221a13450c7a0219a2a0d1b6c9085eb06489721fafd8488ccebc1584175d2fb"
    CMAKE_DIR="$PROJECT_ROOT/Vendor/cmake-${CMAKE_VERSION}-macos-universal"

    if [ ! -d "$CMAKE_DIR" ]; then
        echo "==> Downloading CMake ${CMAKE_VERSION}..."
        cd "$PROJECT_ROOT/Vendor"
        curl -fSL -o "$CMAKE_TAR" "$CMAKE_URL"

        echo "==> Verifying CMake checksum..."
        ACTUAL_SHA=$(shasum -a 256 "$CMAKE_TAR" | awk '{print $1}')
        if [ "$ACTUAL_SHA" != "$CMAKE_SHA256" ]; then
            echo "Error: CMake checksum mismatch!"
            echo "Expected: $CMAKE_SHA256"
            echo "Actual:   $ACTUAL_SHA"
            rm -f "$CMAKE_TAR"
            exit 1
        fi

        echo "==> Extracting CMake..."
        tar xzf "$CMAKE_TAR"
        rm -f "$CMAKE_TAR"
    fi

    CMAKE_BIN="$CMAKE_DIR/CMake.app/Contents/bin/cmake"
    if [ ! -x "$CMAKE_BIN" ]; then
        echo "Error: CMake binary not found at $CMAKE_BIN"
        exit 1
    fi
    echo "==> Using project-local CMake: $CMAKE_BIN"
fi

# --- whisper.cpp ---
WHISPER_DIR="$PROJECT_ROOT/Vendor/whisper.cpp"
WHISPER_TAG="v1.9.1"

if [ ! -d "$WHISPER_DIR/.git" ]; then
    echo "==> Cloning whisper.cpp ${WHISPER_TAG}..."
    git clone --depth 1 --branch "$WHISPER_TAG" \
        https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
else
    echo "==> whisper.cpp already cloned"
fi

# Build whisper.cpp
BUILD_DIR="$WHISPER_DIR/build"
echo "==> Configuring whisper.cpp..."
"$CMAKE_BIN" -S "$WHISPER_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_METAL=ON \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON

echo "==> Building whisper.cpp (4 parallel jobs)..."
"$CMAKE_BIN" --build "$BUILD_DIR" --config Release -j 4

# Install whisper-cli
WHISPER_CLI="$BUILD_DIR/bin/whisper-cli"
if [ ! -f "$WHISPER_CLI" ]; then
    # Try alternate location
    WHISPER_CLI="$BUILD_DIR/bin/Release/whisper-cli"
fi

if [ ! -f "$WHISPER_CLI" ]; then
    echo "Error: whisper-cli not found after build"
    echo "Searched: $BUILD_DIR/bin/"
    ls -la "$BUILD_DIR/bin/" 2>/dev/null || true
    exit 1
fi

echo "==> Installing whisper-cli to Runtime/"
cp "$WHISPER_CLI" "$PROJECT_ROOT/Runtime/whisper-cli"
chmod 755 "$PROJECT_ROOT/Runtime/whisper-cli"

# --- Download model ---
echo "==> Downloading model: $MODEL_NAME..."
cd "$WHISPER_DIR"
bash models/download-ggml-model.sh "$MODEL_NAME"

MODEL_SRC="$WHISPER_DIR/models/${MODEL_FILE}"
if [ ! -f "$MODEL_SRC" ]; then
    echo "Error: Model file not found at $MODEL_SRC"
    exit 1
fi

echo "==> Installing model to Runtime/models/"
cp "$MODEL_SRC" "$PROJECT_ROOT/Runtime/models/${MODEL_FILE}"
chmod 644 "$PROJECT_ROOT/Runtime/models/${MODEL_FILE}"

echo ""
echo "==> Engine setup complete!"
echo "    whisper-cli: $PROJECT_ROOT/Runtime/whisper-cli"
echo "    Model:       $PROJECT_ROOT/Runtime/models/${MODEL_FILE}"
echo ""
echo "Next steps:"
echo "  ./scripts/build-app.sh"
echo "  ./scripts/install-app.sh"
