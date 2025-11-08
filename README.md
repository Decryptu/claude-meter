<p align="center">
  <img width="64" height="64" alt="logo" src="https://github.com/user-attachments/assets/fd5bcb74-816c-4fc0-b284-096567a9f519" />
</p>

<h1 align="center">ClaudeMeter</h1>

<p align="center">
  A native macOS menu bar app that shows your <strong>Claude app usage</strong> in real-time — works with the Claude desktop app or claude.ai in your browser.
  <br/><br/>
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey" alt="Platform: macOS">
  <img src="https://img.shields.io/badge/swift-5.9+-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT">
  <br/><br/>
  <img width="393" height="333" alt="Screenshot" src="https://github.com/user-attachments/assets/e4fb1e3a-1784-4634-a453-8c0091a4ebb6" />
</p>

> ✅ **No API keys required** — ClaudeMeter reads usage from your Claude account session (desktop or browser).  
> ❌ **This is not a tool for the Claude API**.

## Features

- **Automatic Setup** — Detects your Claude Desktop or browser session
- **Menu Bar Integration** — Ring indicator with real-time usage
- **Real-Time Updates** — Refreshes every 60 seconds
- **Smart Quota Refresh** — Keep your 5-hour quota window active automatically
- **Launch at Login** — Toggle from the menu
- **Modern UI** — SwiftUI, native macOS 13-26 interface
- **Built-in Logs** — Debug directly from the menu

## Quick Start

```bash
git clone https://github.com/decryptu/claude-meter.git
cd claude-meter
./run.sh
```

The app will auto-detect your Claude Desktop or browser session and begin monitoring.

## Prerequisites

- macOS 13+
- Swift 5.9+ (Xcode or CLI tools)
- A logged-in Claude account on the desktop app or claude.ai in a browser

No API key needed.

## Installation Options

### Option 1 — Quick Run

```bash
./run.sh
```

### Option 2 — Manual Build

```bash
swift build -c release
./.build/release/ClaudeMeter
```

### Option 3 — Install to Applications

```bash
./Scripts/install.sh
```

## Configuration

### Automatic (Default)

On first launch, ClaudeMeter shows a welcome dialog offering two options:

**Try Auto-Detection** — Automatically detects your Claude session from:
- Claude Desktop cookies
- Brave Browser cookies
- Chrome cookies

You'll be asked to grant Keychain access to decrypt cookies securely.

**Configure Manually** — Skip auto-detection and enter credentials yourself.

If auto-detection succeeds, monitoring starts automatically.

### Manual Setup

If you choose manual setup or auto-detection fails:

1. Click the menu bar icon
2. Open "Settings"
3. Enter credentials manually

To manually retrieve session details:

1. Visit <https://claude.ai/settings/usage> while logged in
2. Open Developer Tools → Network
3. Refresh, inspect the usage request
4. Copy:
   - Organization ID from the URL
   - Session Key from the Cookie header

## Usage

### Dropdown Menu Includes

- Current usage + reset timer
- Refresh (Cmd+R)
- Launch at Login
- Settings (Cmd+,)
- Logs
- Quit (Cmd+Q)

### Smart Quota Refresh

Claude's quota works on a rolling 5-hour window that starts when you send your first message. If you don't use Claude for 5+ hours, the window expires and goes into a "null state."

**Smart Quota Refresh** automatically keeps your quota window active by:
- Detecting when your quota period expires
- Sending a minimal message (~10-20 tokens) to start a new 5-hour window
- Running silently in the background

Enable it in **Settings** → **Smart Quota Refresh** toggle.

This ensures you always have an active quota period ready to use, without wasting tokens on manual messages.

## Troubleshooting

- **"Setup Required"** → Make sure Claude Desktop or claude.ai is logged in
- **No data** → Session may have expired
- **Permissions** → Grant Full Disk Access if needed (for cookie access)

Logs are stored in:

```bash
~/.config/claude-meter/logs/
```

## Building for Distribution

```bash
./Scripts/build-app.sh 1.0.0
```

Unsigned .app will be placed in `dist/`.

Prepare a GitHub release:

```bash
./Scripts/prepare-release.sh 1.0.0
```

## Development

```bash
swift build
swift build -c release
```

Key files:

- `CredentialExtractor.swift`
- `MenuBarManager.swift`
- `SettingsView.swift`
- `Logger.swift`

## Security

- Everything stays on-device
- Only communicates with claude.ai
- No API keys, no telemetry, no tracking
- Open source

## License

MIT — see [LICENSE](LICENSE)

---

Unofficial utility — not affiliated with Anthropic or Claude.

Made with ❤️ for the Claude community.
