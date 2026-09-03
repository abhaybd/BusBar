#!/usr/bin/env bash
# Build BusBar and assemble it into a runnable BusBar.app bundle.
# Usage: ./Scripts/bundle.sh [debug|release]   (default: release)
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="BusBar.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "▸ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/BusBar"

echo "▸ assembling $APP"
rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$BIN_PATH" "$BIN_DIR/BusBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so CoreLocation / launch services are happy on a personal machine.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ built $APP"
echo "  open $APP           # launch via Finder/LaunchServices (reads Info.plist)"
echo "  ./$BIN_DIR/BusBar   # launch directly (inherits shell env, incl. .env)"
