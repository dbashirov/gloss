#!/usr/bin/env bash
# Builds build/Engl.app from the release binary and signs it.
# CODESIGN_IDENTITY selects a stable signing identity, "Engl Local Signing" by default
# when the keychain has it; otherwise the bundle is signed ad-hoc, and Keychain and
# Screen Recording ask for access again after every rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."

APP=build/Engl.app
LOCAL_IDENTITY="Engl Local Signing"
if [[ -z "${CODESIGN_IDENTITY:-}" ]] &&
    security find-identity -p codesigning | grep -q "\"$LOCAL_IDENTITY\""; then
    CODESIGN_IDENTITY="$LOCAL_IDENTITY"
fi
IDENTITY="${CODESIGN_IDENTITY:--}"

swift build -c release --product Engl
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Engl" "$APP/Contents/MacOS/Engl"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/StatusIcon.png Resources/StatusIcon@2x.png \
    "$APP/Contents/Resources/"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

codesign --force --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "built $APP (signed with ${IDENTITY/#-/ad-hoc})"
