#!/bin/bash
# Quick dev cycle: kill → build → codesign → relaunch
set -e

APP="$HOME/Applications/Kapt.app"
BIN="$APP/Contents/MacOS/Kapt"
SIGN_ID="Apple Development: me.nguyentungson@gmail.com (LC36QSW9KK)"

# Kill running instance
pkill -f "Kapt.app" 2>/dev/null || true
sleep 0.3

cd "$(dirname "$0")/.."
swift build -c release 2>&1 | tail -3

cp -f .build/release/Kapt "$BIN"

# Sign with Apple Development cert so macOS preserves permissions across rebuilds
codesign --force --sign "$SIGN_ID" "$APP" 2>&1
echo "✓ Binary updated and signed"

open "$APP"
echo "✓ Kapt relaunched"
