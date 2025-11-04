#!/bin/bash

# ClaudeMeter - Credential Extraction Script
# This script helps extract your Claude session key and organization ID

set -e

echo "=================================="
echo "ClaudeMeter Credential Extractor"
echo "=================================="
echo ""

CONFIG_DIR="$HOME/.config/claude-meter"
CONFIG_FILE="$CONFIG_DIR/settings.json"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

echo "This script will help you extract your Claude credentials."
echo ""
echo "Option 1: Extract from Chrome/Brave browser"
echo "Option 2: Extract from Safari browser"
echo "Option 3: Extract from Claude Desktop app"
echo "Option 4: Manual entry"
echo ""

read -p "Choose an option (1-4): " option

extract_from_chrome_brave() {
    echo ""
    echo "Searching for Claude session in Chrome/Brave..."

    # Common paths for Chrome-based browsers on macOS
    CHROME_PATHS=(
        "$HOME/Library/Application Support/Google/Chrome/Default/Cookies"
        "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies"
        "$HOME/Library/Application Support/Chromium/Default/Cookies"
    )

    for COOKIE_PATH in "${CHROME_PATHS[@]}"; do
        if [ -f "$COOKIE_PATH" ]; then
            echo "Found cookies database at: $COOKIE_PATH"
            echo ""
            echo "To extract your session key:"
            echo "1. Open Chrome/Brave"
            echo "2. Go to https://claude.ai/settings/usage"
            echo "3. Open Developer Tools (Cmd+Option+I)"
            echo "4. Go to Application tab > Cookies > https://claude.ai"
            echo "5. Find 'sessionKey' cookie and copy its value"
            echo "6. Find 'lastActiveOrg' cookie for your organization ID"
            break
        fi
    done
}

extract_from_safari() {
    echo ""
    echo "To extract your session key from Safari:"
    echo "1. Open Safari"
    echo "2. Go to https://claude.ai/settings/usage"
    echo "3. Open Web Inspector (Cmd+Option+I)"
    echo "4. Go to Storage tab > Cookies > https://claude.ai"
    echo "5. Find 'sessionKey' cookie and copy its value"
    echo "6. Find 'lastActiveOrg' cookie for your organization ID"
}

extract_from_desktop_app() {
    echo ""
    echo "Searching for Claude Desktop app data..."

    DESKTOP_APP_PATH="$HOME/Library/Application Support/Claude"

    if [ -d "$DESKTOP_APP_PATH" ]; then
        echo "Found Claude Desktop app data"
        echo ""
        echo "To extract your credentials from Claude Desktop:"
        echo "1. Open Claude Desktop app"
        echo "2. Open Developer Tools (may need to enable first)"
        echo "3. Check local storage or cookies for session information"
        echo ""
        echo "Note: Claude Desktop may store credentials differently."
        echo "You might need to use the browser method instead."
    else
        echo "Claude Desktop app data not found."
        echo "Please use one of the browser methods instead."
    fi
}

manual_entry() {
    echo ""
    echo "Manual credential entry:"
    echo ""
    echo "To find your credentials:"
    echo "1. Open https://claude.ai/settings/usage in your browser"
    echo "2. Open Network tab in Developer Tools"
    echo "3. Refresh the page"
    echo "4. Look for the 'usage' request"
    echo "5. In the Request URL, find your organization ID (the UUID)"
    echo "6. In the Request Headers, find the Cookie header and copy the sessionKey value"
    echo ""

    read -p "Enter your Organization ID: " org_id
    read -p "Enter your Session Key (sk-ant-sid01-...): " session_key

    # Create JSON config file
    cat > "$CONFIG_FILE" <<EOF
{
  "organizationId": "$org_id",
  "sessionKey": "$session_key"
}
EOF

    echo ""
    echo "✅ Configuration saved to: $CONFIG_FILE"
    echo ""
    echo "You can now run ClaudeMeter!"
    return 0
}

case $option in
    1)
        extract_from_chrome_brave
        manual_entry
        ;;
    2)
        extract_from_safari
        manual_entry
        ;;
    3)
        extract_from_desktop_app
        manual_entry
        ;;
    4)
        manual_entry
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
