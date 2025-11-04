#!/bin/bash

# ClaudeMeter - Icon Generator
# Converts PNG to .icns for macOS app bundle

set -e

SOURCE_PNG="tmp/claude-meter-macOS-Default-1024x1024@2x.png"
ICONSET_DIR="AppIcon.iconset"
OUTPUT_ICNS="Resources/AppIcon.icns"

echo "=================================="
echo "ClaudeMeter Icon Generator"
echo "=================================="
echo ""

if [ ! -f "$SOURCE_PNG" ]; then
    echo "❌ Error: Source PNG not found: $SOURCE_PNG"
    exit 1
fi

echo "📐 Source: $SOURCE_PNG"
echo ""

# Create Resources directory
mkdir -p Resources

# Create iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

echo "🎨 Generating icon sizes..."

# Generate all required icon sizes
# macOS requires these specific sizes and naming
sips -z 16 16     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

echo "✅ Generated $(ls $ICONSET_DIR | wc -l | xargs) icon sizes"
echo ""

# Convert to icns
echo "🔨 Converting to .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

if [ -f "$OUTPUT_ICNS" ]; then
    echo "✅ Icon created: $OUTPUT_ICNS"

    # Get file size
    ICON_SIZE=$(du -h "$OUTPUT_ICNS" | awk '{print $1}')
    echo "   Size: $ICON_SIZE"
else
    echo "❌ Error: Failed to create .icns file"
    exit 1
fi

# Cleanup iconset
rm -rf "$ICONSET_DIR"

echo ""
echo "✨ Icon generation complete!"
echo ""
