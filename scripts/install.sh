#!/bin/bash
set -e

APP_NAME="Kapt"
BUNDLE_ID="com.sonpiaz.kapt"
APP_DIR="$HOME/Applications/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME..."
cd "$(dirname "$0")/.."
swift build -c release 2>&1 | tail -3

echo "Creating $APP_NAME.app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp .build/release/SnapX "$MACOS/$APP_NAME"

# Info.plist — LSUIElement so no Dock icon
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Kapt</string>
    <key>CFBundleDisplayName</key>
    <string>Kapt</string>
    <key>CFBundleIdentifier</key>
    <string>com.sonpiaz.kapt</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>Kapt</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Kapt needs screen recording permission to capture screenshots.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Touch to update Spotlight index
touch "$APP_DIR"

echo ""
echo "✓ Installed to $APP_DIR"
echo "✓ Search 'Kapt' in Spotlight (⌘+Space)"
echo ""
echo "Launching $APP_NAME..."
open "$APP_DIR"
