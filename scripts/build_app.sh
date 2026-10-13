#!/usr/bin/env bash
set -e

# Directory setup
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "==> Building WeatherBar release binary with Swift..."
swift build -c release

BIN_PATH="$DIR/.build/release/WeatherBar"
APP_DIR="$DIR/WeatherBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Packaging WeatherBar.app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BIN_PATH" "$MACOS_DIR/WeatherBar"

# Copy AppIcon if available
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist with LSUIElement = true (agent app that sits in the menubar without Dock icon)
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>WeatherBar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.weatherbar.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>WeatherBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc code sign the bundle for macOS security
if which codesign >/dev/null 2>&1; then
    echo "==> Applying ad-hoc signature to WeatherBar.app..."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "==> WeatherBar.app bundle successfully created at:"
echo "    $APP_DIR"
