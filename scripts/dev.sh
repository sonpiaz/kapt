#!/bin/bash
# Quick dev cycle: kill → build → update binary → relaunch
set -e

APP="$HOME/Applications/Kapt.app"
BIN="$APP/Contents/MacOS/Kapt"

# Kill running instance
pkill -f "Kapt.app" 2>/dev/null || true
sleep 0.3

cd "$(dirname "$0")/.."
swift build -c release 2>&1 | tail -3

cp -f .build/release/Kapt "$BIN"
echo "✓ Binary updated"

open "$APP"
echo "✓ Kapt relaunched"
