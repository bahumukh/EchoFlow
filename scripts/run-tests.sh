#!/bin/bash
# run-tests.sh — Compile and run text processor tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building Echoflow text processor tests..."

mkdir -p "$PROJECT_ROOT/.build"

xcrun swiftc \
    -O \
    -target arm64-apple-macos14.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -module-cache-path "$PROJECT_ROOT/.build/ModuleCache" \
    -framework Foundation \
    -o "$PROJECT_ROOT/.build/EchoflowSmokeTests" \
    "$PROJECT_ROOT/Sources/EchoflowTextProcessor.swift" \
    "$PROJECT_ROOT/Tests/TextProcessorTests.swift"

echo "==> Running tests..."
"$PROJECT_ROOT/.build/EchoflowSmokeTests"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "==> All tests passed!"
else
    echo "==> Tests FAILED (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE
