#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/dist"
APP_NAME="Clawy"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."

# Build release binary
cd "$PROJECT_DIR"
swift build -c release 2>&1

# Find the built binary
BINARY="$PROJECT_DIR/.build/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

# Clean previous build
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/hooks"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy hook script
cp "$PROJECT_DIR/hooks/clawy-hook.sh" "$APP_BUNDLE/Contents/Resources/hooks/"
chmod +x "$APP_BUNDLE/Contents/Resources/hooks/clawy-hook.sh"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Clawy</string>
    <key>CFBundleIdentifier</key>
    <string>com.danmana.clawy</string>
    <key>CFBundleName</key>
    <string>Clawy</string>
    <key>CFBundleDisplayName</key>
    <string>Clawy</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc code sign (prevents "damaged app" error on other Macs)
codesign --force --deep --sign - "$APP_BUNDLE"

# Create zip for distribution
cd "$BUILD_DIR"
zip -r "$APP_NAME.zip" "$APP_NAME.app" > /dev/null

echo ""
echo "✅ Built successfully!"
echo "   App:  $APP_BUNDLE"
echo "   Zip:  $BUILD_DIR/$APP_NAME.zip"
echo "   Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
echo "To install: drag $APP_NAME.app to /Applications"
echo "To share:   send $APP_NAME.zip"
