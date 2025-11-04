# ClaudeMeter

A native macOS menu bar application that displays your Claude AI usage statistics in real-time with **automatic credential detection**.

<img src="https://img.shields.io/badge/platform-macOS-lightgrey" alt="Platform: macOS"> <img src="https://img.shields.io/badge/swift-5.9+-orange" alt="Swift 5.9+"> <img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT">

## ✨ Features

- **Automatic Setup**: Automatically detects credentials from Claude Desktop or your browser
- **Menu Bar Integration**: Lives in your macOS menu bar, just like the battery indicator
- **Real-Time Usage**: Shows your current Claude usage percentage with a visual ring indicator
- **Color-Coded Status**: Green (0-49%), Yellow (50-79%), Red (80-100%)
- **Detailed Information**: Click to see detailed usage stats including time until reset
- **Launch at Login**: Toggle startup behavior directly from the menu
- **Modern SwiftUI Interface**: Native macOS 15 Sequoia support
- **Comprehensive Logging**: Built-in logging system for troubleshooting
- **Auto-Refresh**: Automatically updates every 60 seconds
- **Lightweight**: Native Swift application with minimal resource usage

## 🚀 Quick Start (Recommended)

The easiest way to get started:

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-meter.git
cd claude-meter

# Run the app (builds automatically)
./run.sh
```

That's it! ClaudeMeter will:
1. Auto-detect credentials from Claude Desktop or your browser
2. Build and launch the app
3. Start monitoring your usage immediately

All logs are saved to `~/.config/claude-meter/logs/` for troubleshooting.

## 📋 Prerequisites

- **macOS 13.0 or later** (optimized for macOS 15 Sequoia)
- **Swift 5.9+** (comes with Xcode or Xcode Command Line Tools)
- **An active Claude AI account**
- **One of the following**:
  - Claude Desktop app (installed and logged in)
  - Brave, Chrome, or Safari (with active Claude session)

## 📦 Installation

### Option 1: Quick Run (Recommended)

```bash
./run.sh
```

### Option 2: Build and Run Manually

```bash
swift build -c release
./.build/release/ClaudeMeter
```

### Option 3: Install to Applications

```bash
./Scripts/install.sh
```

This will:
- Build the release version
- Copy to `~/Applications/ClaudeMeter/`
- Optionally set up auto-start on login

## ⚙️ Configuration

### Automatic Detection (Preferred)

ClaudeMeter automatically searches for credentials in:

1. **Claude Desktop** (`~/Library/Application Support/Claude/Cookies`)
2. **Brave Browser** (`~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies`)
3. **Google Chrome** (`~/Library/Application Support/Google/Chrome/Default/Cookies`)

On first run, it will:
- Search these locations for your session data
- Extract your Organization ID and Session Key
- Save them automatically
- Start monitoring immediately

If auto-detection succeeds, you'll see a notification confirming the source.

### Manual Configuration

If auto-detection fails, click the app icon and select **"Configure Settings..."**

The modern SwiftUI settings window allows you to:
1. **Auto-Detect**: Try automatic detection again
2. **Manual Entry**: Enter credentials manually

#### Finding Credentials Manually

1. Open [https://claude.ai/settings/usage](https://claude.ai/settings/usage)
2. Open Developer Tools (`Cmd + Option + I`)
3. Go to **Network** tab
4. Refresh the page
5. Click the `usage` request
6. Find:
   - **Organization ID**: In the request URL (UUID format)
   - **Session Key**: In Cookie header (starts with `sk-ant-sid01-`)

Example:
```
URL: https://claude.ai/api/organizations/[YOUR-ORG-ID]/usage
Cookie: sessionKey=[YOUR-SESSION-KEY]; ...
```

## 🎯 Usage

Once running, ClaudeMeter displays in your menu bar:

### Menu Bar Icon
- **Ring indicator**: Fills clockwise based on usage percentage
- **Percentage text**: Shows current usage (e.g., "47%")
- **Color**: Changes from green → yellow → red as usage increases

### Dropdown Menu

Click the icon to see:

**When Configured:**
- Current session usage percentage
- Time until reset
- Last update time
- **Refresh Now** (`Cmd + R`) - Manual refresh
- **Launch at Login** - Toggle checkbox for auto-start
- **Settings...** (`Cmd + ,`) - Open settings window
- **View Logs** - Open log file for troubleshooting
- **Quit ClaudeMeter** (`Cmd + Q`)

**When Not Configured:**
- Setup Required warning
- Configure Settings option
- View Logs option

### Launch at Login

Toggle directly from the menu to enable/disable auto-start. Uses native macOS APIs:
- macOS 13+: `SMAppService`
- macOS 12 and below: Launch Agent plist

## 🔍 Troubleshooting

### View Logs

Click **View Logs** from the menu to open the current log file. Logs include:
- Credential detection attempts
- API requests and responses
- Errors and warnings
- All user actions

Logs are stored in: `~/.config/claude-meter/logs/`

### Common Issues

#### "Setup Required" on First Run

**Cause**: Auto-detection didn't find credentials

**Solutions**:
1. Make sure you're logged into Claude (Desktop or Web)
2. Click "Configure Settings" → "Auto-Detect" to try again
3. Check logs to see what was searched
4. Enter credentials manually if needed

#### Settings Window Shows Glitched Fields

**This has been fixed!** The new version uses SwiftUI with proper macOS 15 support.

#### No Data Showing After Configuration

**Possible causes**:
- Session key expired
- Network issues
- Incorrect organization ID

**Solutions**:
1. Check logs for API errors
2. Verify you're logged into claude.ai
3. Try refreshing credentials
4. Use "Auto-Detect" to get fresh credentials

#### Permission Errors When Reading Cookies

**Cause**: macOS security restrictions

**Solution**: Grant Full Disk Access:
1. System Settings → Privacy & Security
2. Full Disk Access
3. Add Terminal (if running from terminal)
4. Or add ClaudeMeter app

#### Launch at Login Not Working

**Solutions**:
1. Check System Settings → General → Login Items
2. Remove and re-add via the app menu
3. Check logs for error messages

## 🛠️ Development

### Project Structure

```
claude-meter/
├── Package.swift                     # Swift Package Manager config
├── run.sh                            # Quick run script (NEW)
├── Sources/
│   ├── main.swift                   # App entry point
│   ├── AppDelegate.swift            # Application delegate
│   ├── MenuBarManager.swift         # Menu bar logic
│   ├── ClaudeAPIClient.swift        # API client with logging
│   ├── Models.swift                 # Data models
│   ├── Logger.swift                 # Logging system (NEW)
│   ├── CredentialExtractor.swift    # Auto-detection (NEW)
│   ├── SettingsView.swift           # SwiftUI settings (NEW)
│   └── LaunchAtLoginHelper.swift    # Startup management (NEW)
├── Scripts/
│   ├── extract-credentials.sh       # Legacy credential helper
│   ├── build.sh                     # Build script
│   └── install.sh                   # Installation script
└── README.md
```

### Building

```bash
# Debug build with verbose output
swift build

# Release build (optimized)
swift build -c release

# Run debug build
./.build/debug/ClaudeMeter

# Run release build
./.build/release/ClaudeMeter
```

### Adding Features

The codebase is well-structured:
- **Logger.swift**: Add logging to any component via `Logger.shared.log()`
- **CredentialExtractor.swift**: Add support for more browsers or storage formats
- **SettingsView.swift**: Customize the settings UI
- **MenuBarManager.swift**: Add menu items or change behavior

## 🔒 Security & Privacy

### Local Storage Only
- Credentials stored in `~/.config/claude-meter/settings.json`
- File permissions restricted to your user account
- Never transmitted to third parties

### Network Communication
- Only communicates with `claude.ai` API endpoints
- Uses standard HTTPS
- No analytics or tracking

### Credential Extraction
- Reads cookies from local browser/app databases
- Creates temporary copies to avoid locks
- No modification of original data
- Fully transparent logging

### Session Key Expiration

Claude session keys expire periodically. When this happens:
1. ClaudeMeter will show errors in logs
2. Use "Auto-Detect" to get fresh credentials
3. Or manually update via Settings

## 📈 Future Enhancements

- [ ] Decrypt encrypted cookies (Chrome v10+ format)
- [ ] Safari binary cookie support
- [ ] Usage history tracking and graphs
- [ ] Notifications when approaching limits
- [ ] Multiple organization support
- [ ] Customizable refresh intervals
- [ ] Export usage data to CSV/JSON
- [ ] Signed .app bundle for distribution

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Fork the repository
2. Clone your fork
3. Make changes
4. Test thoroughly on macOS
5. Submit PR with description

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

## 🙏 Acknowledgments

- Built with Swift and SwiftUI
- Inspired by macOS system status items
- Uses Claude AI's public API
- Community feedback and contributions

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/claude-meter/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/claude-meter/discussions)
- **Logs**: Always check logs first via "View Logs" menu option

---

**Note**: This is an unofficial tool and is not affiliated with or endorsed by Anthropic or Claude AI.

Made with ❤️ for the Claude community
