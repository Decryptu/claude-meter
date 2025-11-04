#!/bin/bash

# ClaudeMeter - App Bundle Builder
# Creates an unsigned .app bundle for distribution

set -e

VERSION=${1:-"1.0.0"}
APP_NAME="ClaudeMeter"
BUNDLE_ID="com.claudemeter.app"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "=================================="
echo "ClaudeMeter App Bundle Builder"
echo "=================================="
echo ""
echo "Version: $VERSION"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script only works on macOS"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build the release binary
echo "🔨 Building release binary..."
swift build -c release

if [ ! -f ".build/release/$APP_NAME" ]; then
    echo "❌ Error: Build failed, executable not found"
    exit 1
fi

echo "✅ Build complete"
echo ""

# Create .app bundle structure
echo "📦 Creating .app bundle structure..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "✅ Icon included"
else
    echo "⚠️  Warning: Icon not found (run ./Scripts/generate-icon.sh first)"
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
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

echo "✅ Bundle structure created"
echo ""

# Ad-hoc code signing (unsigned but with basic signature)
echo "🔏 Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

if [ $? -eq 0 ]; then
    echo "✅ Code signed (ad-hoc)"
else
    echo "⚠️  Warning: Code signing failed, but bundle is still usable"
fi

echo ""

# Create ZIP for distribution
echo "📦 Creating distributable ZIP..."
cd "$DIST_DIR"
zip -r "$APP_NAME-$VERSION.zip" "$APP_NAME.app" > /dev/null
cd ..

echo "✅ ZIP created: $DIST_DIR/$APP_NAME-$VERSION.zip"
echo ""

# Calculate file sizes
APP_SIZE=$(du -h "$APP_BUNDLE" | tail -1 | awk '{print $1}')
ZIP_SIZE=$(du -h "$DIST_DIR/$APP_NAME-$VERSION.zip" | awk '{print $1}')

echo "=================================="
echo "✨ Build Complete!"
echo "=================================="
echo ""
echo "📁 App Bundle: $APP_BUNDLE ($APP_SIZE)"
echo "📦 ZIP File:   $DIST_DIR/$APP_NAME-$VERSION.zip ($ZIP_SIZE)"
echo ""
echo "To test locally:"
echo "  open $APP_BUNDLE"
echo ""
echo "To distribute:"
echo "  Upload $DIST_DIR/$APP_NAME-$VERSION.zip to GitHub Releases"
echo ""
echo "Users can:"
echo "  1. Download and unzip"
echo "  2. Move $APP_NAME.app to /Applications"
echo "  3. Right-click and select 'Open' (first time only)"
echo "  4. Grant permissions if prompted"
echo ""
