#!/bin/bash

# ClaudeMeter - Single Run Script
# This script builds and runs ClaudeMeter with automatic credential detection

set -e

echo "=================================="
echo "ClaudeMeter - Quick Start"
echo "=================================="
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This application only works on macOS"
    exit 1
fi

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed"
    echo "Please install Xcode from the Mac App Store or the Swift toolchain from swift.org"
    exit 1
fi

echo "✅ macOS detected: $(sw_vers -productVersion)"
echo "✅ Swift version: $(swift --version | head -1)"
echo ""

# Build the project
echo "🔨 Building ClaudeMeter..."
if swift build -c release 2>&1 | grep -v "\.swiftpm" | grep -v "\.build"; then
    echo ""
    echo "✅ Build complete!"
else
    echo ""
    echo "❌ Build failed. Check the errors above."
    exit 1
fi

echo ""
echo "🚀 Starting ClaudeMeter..."
echo ""
echo "📋 Logs will be saved to: ~/.config/claude-meter/logs/"
echo "   You can view logs from the app menu: View Logs"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run the app
./.build/release/ClaudeMeter
