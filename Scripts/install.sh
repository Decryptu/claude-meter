#!/bin/bash

# ClaudeMeter - Installation Script

set -e

echo "=================================="
echo "ClaudeMeter Installation"
echo "=================================="
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This application only works on macOS"
    exit 1
fi

# Build the project
echo "Building ClaudeMeter..."
swift build -c release

# Create Applications directory if it doesn't exist
INSTALL_DIR="$HOME/Applications/ClaudeMeter"
mkdir -p "$INSTALL_DIR"

# Copy the executable
echo "Installing to $INSTALL_DIR..."
cp .build/release/ClaudeMeter "$INSTALL_DIR/"

# Create a launch agent plist for auto-start (optional)
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.claudemeter.agent.plist"

read -p "Would you like ClaudeMeter to start automatically on login? (y/n): " autostart

if [[ $autostart == "y" || $autostart == "Y" ]]; then
    mkdir -p "$PLIST_DIR"

    cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claudemeter.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/ClaudeMeter</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

    echo "✅ Launch agent created"
    echo "To start now: launchctl load $PLIST_FILE"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "To run ClaudeMeter: $INSTALL_DIR/ClaudeMeter"
echo ""
echo "Next steps:"
echo "1. Run the credential extractor: ./Scripts/extract-credentials.sh"
echo "2. Start ClaudeMeter: $INSTALL_DIR/ClaudeMeter"
