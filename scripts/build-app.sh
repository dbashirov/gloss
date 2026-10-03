#!/usr/bin/env bash
# Builds build/Engl.app from the release binary and signs it.
# CODESIGN_IDENTITY selects a stable signing identity; without it the bundle is
# signed ad-hoc and Keychain asks for access again after every rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."

APP=build/Engl.app
IDENTITY="${CODESIGN_IDENTITY:--}"

swift build -c release --product Engl
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Engl" "$APP/Contents/MacOS/Engl"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

codesign --force --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "built $APP (signed with ${IDENTITY/#-/ad-hoc})"
