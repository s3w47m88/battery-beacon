#!/bin/bash
set -euo pipefail

APP_NAME="MacOS Fully Battery Alert"
BUNDLE_ID="com.spencerhill.fullbatteryalert"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
BIN_NAME="FullBatteryAlert"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"

echo "Compiling…"
swiftc -O \
  -target arm64-apple-macos14.0 \
  -framework AppKit -framework SwiftUI -framework UserNotifications -framework IOKit -framework Combine \
  -o "$MACOS_DIR/$BIN_NAME" \
  Sources/FullBatteryAlert/*.swift

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$BIN_NAME</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built: $APP_DIR"
