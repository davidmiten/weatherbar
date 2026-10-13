#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

BUILD_DMG=false
BUILD_ZIP=false
INSTALL=false
INSTALL_DIR="/Applications"
LAUNCH_AFTER=true

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --install           Install WeatherBar.app directly into /Applications"
    echo "  --user              Install to ~/Applications instead of /Applications"
    echo "  --dmg               Create a drag-and-drop disk image installer (dist/WeatherBar.dmg)"
    echo "  --zip               Create a zip distribution archive (dist/WeatherBar.zip)"
    echo "  --all               Build app, DMG, ZIP, and install to /Applications"
    echo "  --no-launch         Do not launch the app after installation"
    echo "  -h, --help          Show this help message"
    echo ""
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)
            INSTALL=true
            shift
            ;;
        --user)
            INSTALL=true
            INSTALL_DIR="$HOME/Applications"
            shift
            ;;
        --dmg)
            BUILD_DMG=true
            shift
            ;;
        --zip)
            BUILD_ZIP=true
            shift
            ;;
        --all)
            INSTALL=true
            BUILD_DMG=true
            BUILD_ZIP=true
            shift
            ;;
        --no-launch)
            LAUNCH_AFTER=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# If no flags passed, default to building the app and creating a DMG installer
if [ "$INSTALL" = false ] && [ "$BUILD_DMG" = false ] && [ "$BUILD_ZIP" = false ]; then
    BUILD_DMG=true
fi

# Step 1: Build the .app bundle
echo "=========================================="
echo " Packaging WeatherBar for macOS"
echo "=========================================="
./scripts/build_app.sh

APP_BUNDLE="$DIR/WeatherBar.app"
DIST_DIR="$DIR/dist"
mkdir -p "$DIST_DIR"

# Step 2: Build DMG if requested
if [ "$BUILD_DMG" = true ]; then
    echo ""
    echo "==> Creating macOS Drag-and-Drop DMG installer..."
    DMG_NAME="WeatherBar.dmg"
    DMG_PATH="$DIST_DIR/$DMG_NAME"
    DMG_TEMP_DIR="$DIR/.build/dmg_staging"

    rm -rf "$DMG_TEMP_DIR" "$DMG_PATH"
    mkdir -p "$DMG_TEMP_DIR"

    # Copy WeatherBar.app into staging
    cp -R "$APP_BUNDLE" "$DMG_TEMP_DIR/"

    # Create Applications symlink for drag-and-drop installation
    ln -s /Applications "$DMG_TEMP_DIR/Applications"

    # Create DMG disk image
    hdiutil create -volname "WeatherBar Installer" \
                   -srcfolder "$DMG_TEMP_DIR" \
                   -ov \
                   -format UDZO \
                   "$DMG_PATH" > /dev/null

    rm -rf "$DMG_TEMP_DIR"
    echo "==> DMG installer created at:"
    echo "    $DMG_PATH"
fi

# Step 3: Build ZIP if requested
if [ "$BUILD_ZIP" = true ]; then
    echo ""
    echo "==> Creating ZIP distribution archive..."
    ZIP_NAME="WeatherBar-1.0.0.zip"
    ZIP_PATH="$DIST_DIR/$ZIP_NAME"
    rm -f "$ZIP_PATH"
    (cd "$DIR" && ditto -c -k --sequesterRsrc --keepParent "WeatherBar.app" "$ZIP_PATH")
    echo "==> ZIP archive created at:"
    echo "    $ZIP_PATH"
fi

# Step 4: Install to Applications if requested
if [ "$INSTALL" = true ]; then
    echo ""
    echo "==> Installing WeatherBar to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    TARGET_APP="$INSTALL_DIR/WeatherBar.app"

    # Stop running instance if any
    if pgrep -x "WeatherBar" > /dev/null 2>&1; then
        echo "==> Closing currently running WeatherBar instance..."
        killall WeatherBar 2>/dev/null || true
        sleep 1
    fi

    # Copy app bundle to Applications folder
    rm -rf "$TARGET_APP"
    cp -R "$APP_BUNDLE" "$TARGET_APP"

    # Remove quarantine attribute and re-sign in destination
    xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
    if which codesign >/dev/null 2>&1; then
        codesign --force --deep --sign - "$TARGET_APP" >/dev/null 2>&1 || true
    fi

    # Refresh LaunchServices registry
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$TARGET_APP" 2>/dev/null || true

    echo "==> Successfully installed WeatherBar to:"
    echo "    $TARGET_APP"

    if [ "$LAUNCH_AFTER" = true ]; then
        echo "==> Launching WeatherBar from $INSTALL_DIR..."
        open "$TARGET_APP"
        echo "==> WeatherBar is now active in your menu bar next to the clock!"
    fi
fi

echo ""
echo "=========================================="
echo " Packaging Complete!"
echo "=========================================="
