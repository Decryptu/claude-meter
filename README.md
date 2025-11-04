# ClaudeMeter

A native macOS menu bar app that displays your Claude AI usage in real-time with **automatic credential detection**.

<img src="https://img.shields.io/badge/platform-macOS-lightgrey" alt="Platform: macOS"> <img src="https://img.shields.io/badge/swift-5.9+-orange" alt="Swift 5.9+"> <img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT">

## Features

- **Automatic Setup** - Detects credentials from Claude Desktop or your browser
- **Menu Bar Integration** - Ring indicator with percentage and color coding (green/yellow/red)
- **Real-Time Updates** - Auto-refreshes every 60 seconds
- **Launch at Login** - Toggle directly from menu
- **Modern UI** - Native macOS 26 support with SwiftUI
- **Built-in Logging** - View logs from the app menu

## Quick Start

```bash
git clone https://github.com/yourusername/claude-meter.git
cd claude-meter
./run.sh
```

That's it! The app will auto-detect your credentials and start monitoring.

## Prerequisites

- macOS 13+ (optimized for macOS 26)
- Swift 5.9+ (Xcode or Command Line Tools)
- Claude account (Desktop app or browser session)

## Installation Options

**Option 1: Quick Run**
```bash
./run.sh
```

**Option 2: Manual Build**
```bash
swift build -c release
./.build/release/ClaudeMeter
```

**Option 3: Install to Applications**
```bash
./Scripts/install.sh
```

## Configuration

### Automatic (Default)

On first run, ClaudeMeter searches for credentials in:
- Claude Desktop cookies
- Brave Browser cookies
- Chrome cookies

If found, you'll see a notification and the app starts working immediately.

### Manual Setup

If auto-detection fails:
1. Click the menu bar icon
2. Select "Configure Settings..."
3. Click "Auto-Detect" or enter credentials manually

To find credentials manually:
1. Go to https://claude.ai/settings/usage
2. Open Developer Tools (Cmd+Option+I) → Network tab
3. Refresh and find the `usage` request
4. Copy Organization ID from URL and Session Key from Cookie header

## Usage

**Menu Bar Icon:**
- Ring fills clockwise based on usage %
- Color changes: green (0-49%) → yellow (50-79%) → red (80-100%)

**Dropdown Menu:**
- Current usage and time until reset
- Refresh Now (Cmd+R)
- Launch at Login toggle
- Settings (Cmd+,)
- View Logs
- Quit (Cmd+Q)

## Troubleshooting

**View Logs:** Click "View Logs" in the menu. Logs are in `~/.config/claude-meter/logs/`

**Common Issues:**

- **"Setup Required"** - Make sure you're logged into Claude, then try "Auto-Detect" in Settings
- **No data showing** - Check logs for errors, session key may be expired
- **Permission errors** - Grant Full Disk Access to Terminal or the app in System Settings

## Building for Distribution

**Create .app bundle:**
```bash
./Scripts/build-app.sh 1.0.0
```

This creates an unsigned .app bundle in `dist/` ready for distribution.

**Prepare GitHub release:**
```bash
./Scripts/prepare-release.sh 1.0.0
```

This builds the app and creates a release package with checksums and notes.

## Development

**Build for testing:**
```bash
swift build          # Debug
swift build -c release  # Release
```

**Key Files:**
- `Sources/CredentialExtractor.swift` - Auto-detection
- `Sources/MenuBarManager.swift` - Menu bar logic
- `Sources/SettingsView.swift` - SwiftUI settings
- `Sources/Logger.swift` - Logging system

## Security

- Credentials stored locally in `~/.config/claude-meter/settings.json`
- Only communicates with `claude.ai` API
- No analytics or tracking
- Open source and transparent

## License

MIT License - see [LICENSE](LICENSE)

---

**Unofficial tool** - Not affiliated with Anthropic or Claude AI

Made with ❤️ for the Claude community
