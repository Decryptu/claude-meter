#!/bin/bash

# ClaudeMeter - GitHub Release Preparation Script
# Prepares a complete release package for GitHub

set -e

if [ -z "$1" ]; then
    echo "Usage: ./Scripts/prepare-release.sh <version>"
    echo "Example: ./Scripts/prepare-release.sh 1.0.0"
    exit 1
fi

VERSION="$1"
DIST_DIR="dist"
RELEASE_DIR="$DIST_DIR/release-$VERSION"

echo "=================================="
echo "ClaudeMeter Release Preparation"
echo "=================================="
echo ""
echo "Version: $VERSION"
echo ""

# Clean and create release directory
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Build the app bundle
echo "🔨 Building app bundle..."
./Scripts/build-app.sh "$VERSION"

# Copy ZIP to release directory
cp "$DIST_DIR/ClaudeMeter-$VERSION.zip" "$RELEASE_DIR/"

# Create release notes template
cat > "$RELEASE_DIR/RELEASE_NOTES.md" <<EOF
# ClaudeMeter v$VERSION

## What's New

- [Add your changes here]

## Installation

### For macOS Users

1. Download \`ClaudeMeter-$VERSION.zip\`
2. Unzip the file
3. Move \`ClaudeMeter.app\` to your Applications folder
4. **Important**: Right-click the app and select "Open" (first time only)
5. Click "Open" in the security dialog
6. The app will appear in your menu bar

### First Run

ClaudeMeter will automatically detect your Claude credentials from:
- Claude Desktop app
- Brave Browser
- Google Chrome

If auto-detection fails, click the menu bar icon and select "Configure Settings".

## Requirements

- macOS 13.0 or later
- Active Claude AI account

## Troubleshooting

If you see "App is damaged" or similar errors:
\`\`\`bash
xattr -cr /Applications/ClaudeMeter.app
\`\`\`

For other issues, check logs via the "View Logs" menu option.

## Checksums

\`\`\`
[Checksums will be added below]
\`\`\`
EOF

# Generate checksums
echo "" >> "$RELEASE_DIR/RELEASE_NOTES.md"
echo "SHA256:" >> "$RELEASE_DIR/RELEASE_NOTES.md"
shasum -a 256 "$RELEASE_DIR/ClaudeMeter-$VERSION.zip" | awk '{print $1}' >> "$RELEASE_DIR/RELEASE_NOTES.md"

echo ""
echo "✅ Release package prepared!"
echo ""
echo "📁 Release directory: $RELEASE_DIR"
echo ""
echo "Contents:"
ls -lh "$RELEASE_DIR"
echo ""
echo "Next steps:"
echo ""
echo "1. Review and edit: $RELEASE_DIR/RELEASE_NOTES.md"
echo "2. Create GitHub release:"
echo "   - Go to https://github.com/yourusername/claude-meter/releases/new"
echo "   - Tag: v$VERSION"
echo "   - Title: ClaudeMeter v$VERSION"
echo "   - Copy content from RELEASE_NOTES.md"
echo "   - Upload: $RELEASE_DIR/ClaudeMeter-$VERSION.zip"
echo "3. Publish release"
echo ""
