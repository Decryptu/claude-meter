# ClaudeMeter

A native macOS menu bar application that displays your Claude AI usage statistics in real-time.

<img src="https://img.shields.io/badge/platform-macOS-lightgrey" alt="Platform: macOS"> <img src="https://img.shields.io/badge/swift-5.9+-orange" alt="Swift 5.9+"> <img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT">

## Features

- **Menu Bar Integration**: Lives in your macOS menu bar, just like the battery indicator
- **Real-Time Usage**: Shows your current Claude usage percentage with a visual ring indicator
- **Color-Coded Status**: Green (0-49%), Yellow (50-79%), Red (80-100%)
- **Detailed Information**: Click to see detailed usage stats including time until reset
- **Auto-Refresh**: Automatically updates every 60 seconds
- **Lightweight**: Native Swift application with minimal resource usage

## Screenshots

The menu bar shows:
- A circular ring indicator that fills based on your usage percentage
- The percentage number next to the icon
- Detailed dropdown with reset time and last update

## Prerequisites

- macOS 13.0 or later
- Swift 5.9+ (comes with Xcode)
- An active Claude AI account

## Installation

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/claude-meter.git
   cd claude-meter
   ```

2. **Run the installation script**:
   ```bash
   ./Scripts/install.sh
   ```

3. **Extract your credentials**:
   ```bash
   ./Scripts/extract-credentials.sh
   ```

4. **Launch ClaudeMeter**:
   ```bash
   ~/Applications/ClaudeMeter/ClaudeMeter
   ```

### Manual Build

If you prefer to build manually:

```bash
swift build -c release
./.build/release/ClaudeMeter
```

## Configuration

ClaudeMeter requires two pieces of information from your Claude account:

1. **Organization ID**: A UUID that identifies your Claude organization
2. **Session Key**: Your authentication token (starts with `sk-ant-sid01-`)

### Finding Your Credentials

#### Method 1: Using Browser Developer Tools (Recommended)

1. Open your browser and go to [https://claude.ai/settings/usage](https://claude.ai/settings/usage)
2. Open Developer Tools:
   - Chrome/Brave: `Cmd + Option + I`
   - Safari: `Cmd + Option + I` (enable Developer menu first in Safari preferences)
3. Go to the **Network** tab
4. Refresh the page
5. Look for a request to `usage` in the network list
6. Click on it and examine:
   - **Request URL**: Contains your Organization ID (the UUID in the URL)
     - Example: `https://claude.ai/api/organizations/YOUR-ORG-ID-HERE/usage`
   - **Request Headers** > **Cookie**: Contains your Session Key
     - Look for: `sessionKey=sk-ant-sid01-...`

#### Method 2: Using the Extraction Script

Run the helper script which will guide you through the process:

```bash
./Scripts/extract-credentials.sh
```

#### Method 3: Using the App Settings

1. Launch ClaudeMeter
2. Click on the menu bar icon
3. Select "Configure Settings..."
4. Enter your Organization ID and Session Key
5. Click "Save"

### Configuration File Location

Credentials are stored at: `~/.config/claude-meter/settings.json`

Example format:
```json
{
  "organizationId": "6e35a193-deaa-46a0-80bd-f7a1652d383f",
  "sessionKey": "sk-ant-sid01-YOUR-SESSION-KEY-HERE"
}
```

## Usage

Once configured and running, ClaudeMeter will:

1. **Display in Menu Bar**: Shows a ring icon with your current usage percentage
2. **Auto-Update**: Refreshes every 60 seconds automatically
3. **Click for Details**: Click the icon to see:
   - Current session usage percentage
   - Time until reset
   - Last update time
   - Manual refresh option
   - Settings access
   - Quit option

### Menu Options

- **Refresh Now** (`Cmd + R`): Manually refresh usage data
- **Settings** (`Cmd + ,`): Update your credentials
- **Quit ClaudeMeter** (`Cmd + Q`): Exit the application

## Running at Login

To have ClaudeMeter start automatically when you log in:

1. During installation, answer "yes" when asked about auto-start
2. Or manually create a Launch Agent:
   ```bash
   cp Scripts/com.claudemeter.agent.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.claudemeter.agent.plist
   ```

To disable auto-start:
```bash
launchctl unload ~/Library/LaunchAgents/com.claudemeter.agent.plist
rm ~/Library/LaunchAgents/com.claudemeter.agent.plist
```

## Security & Privacy

### Session Key Security

- Your session key is stored locally in `~/.config/claude-meter/settings.json`
- The file is only accessible by your user account
- ClaudeMeter only communicates with `claude.ai` API endpoints
- No data is sent to any third parties

### Session Key Expiration

Claude session keys can expire. If ClaudeMeter stops working:

1. Go to [claude.ai](https://claude.ai) and verify you're logged in
2. Extract a fresh session key using the methods above
3. Update your settings in ClaudeMeter

## Troubleshooting

### "Setup Required" Message

**Cause**: No credentials configured or invalid credentials file

**Solution**: Run `./Scripts/extract-credentials.sh` or use the Settings menu

### No Data Showing

**Cause**: Session key may be expired or invalid

**Solution**:
1. Visit [claude.ai](https://claude.ai) to verify you're logged in
2. Extract fresh credentials
3. Update settings in ClaudeMeter

### Build Errors

**Cause**: Swift version mismatch or missing Xcode

**Solution**:
1. Install Xcode from the Mac App Store
2. Run `xcode-select --install`
3. Verify Swift: `swift --version`

### API Errors

**Cause**: Network issues or API changes

**Solution**:
1. Check your internet connection
2. Verify claude.ai is accessible
3. Check GitHub issues for known problems

## Development

### Project Structure

```
claude-meter/
├── Package.swift              # Swift Package Manager config
├── Sources/
│   ├── main.swift            # App entry point
│   ├── AppDelegate.swift     # Application delegate
│   ├── MenuBarManager.swift  # Menu bar logic
│   ├── ClaudeAPIClient.swift # API client
│   └── Models.swift          # Data models
├── Scripts/
│   ├── extract-credentials.sh # Credential helper
│   ├── build.sh              # Build script
│   └── install.sh            # Installation script
└── README.md
```

### Building for Development

```bash
# Debug build
swift build

# Run debug build
./.build/debug/ClaudeMeter

# Release build
swift build -c release
```

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## API Reference

ClaudeMeter uses the Claude AI usage API endpoint:

```
GET https://claude.ai/api/organizations/{organizationId}/usage
```

**Response Format**:
```json
{
    "five_hour": {
        "utilization": 47.0,
        "resets_at": "2025-11-04T18:59:59.568116+00:00"
    },
    "seven_day": null,
    "seven_day_oauth_apps": null,
    "seven_day_opus": null,
    "iguana_necktie": null
}
```

## Limitations

- **macOS Only**: This is a native macOS application
- **Session Key Management**: Requires manual session key updates when expired
- **5-Hour Window**: Currently only displays the 5-hour usage window (as provided by Claude's API)

## Future Enhancements

Potential features for future versions:

- [ ] Automatic session key extraction from browsers
- [ ] Support for multiple organizations
- [ ] Usage history tracking and graphs
- [ ] Notifications when approaching limits
- [ ] Dark mode icon variants
- [ ] Customizable refresh intervals
- [ ] Export usage data

## License

MIT License - feel free to use this project however you'd like!

## Acknowledgments

- Built with Swift and SwiftUI
- Inspired by macOS system status items
- Uses Claude AI's public API

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/claude-meter/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/claude-meter/discussions)

---

**Note**: This is an unofficial tool and is not affiliated with or endorsed by Anthropic or Claude AI.
