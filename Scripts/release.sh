#!/usr/bin/env bash
# Build a universal, signed BusBar.app and zip it for a GitHub release.
#
#   ./Scripts/release.sh
#
# Ad-hoc signs by default (works on your machine; other users must clear quarantine — see README).
# For clean distribution, set a Developer ID to enable notarization:
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="BusBar.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo 0.1)"

# Build each arch separately and lipo them together. (A combined `swift build --arch a --arch b`
# needs full Xcode; per-arch builds work with just the Command Line Tools.)
echo "▸ building arm64 slice"
swift build -c release --arch arm64
ARM="$(swift build -c release --arch arm64 --show-bin-path)/BusBar"

echo "▸ building x86_64 slice"
swift build -c release --arch x86_64
X86="$(swift build -c release --arch x86_64 --show-bin-path)/BusBar"

echo "▸ assembling $APP (universal)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM" "$X86" -output "$APP/Contents/MacOS/BusBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
  echo "▸ codesign (ad-hoc)"
  codesign --force --deep --sign - "$APP"
else
  echo "▸ codesign (Developer ID: $IDENTITY) + hardened runtime"
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"
echo "  architectures: $(lipo -archs "$APP/Contents/MacOS/BusBar")"

ZIP="BusBar-${VERSION}-macos.zip"
echo "▸ zipping -> $ZIP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
echo "✓ $ZIP ($(du -h "$ZIP" | cut -f1))"
echo
echo "Next:"
echo "  • Local install:  make install"
echo "  • GitHub release: gh release create v${VERSION} $ZIP --title \"BusBar ${VERSION}\" --notes \"...\""
