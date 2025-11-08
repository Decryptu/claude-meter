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
  <img width="866" height="541" alt="Screenshot" src="https://github.com/user-attachments/assets/598d12c5-2ff9-4c98-920b-b7ab65cc5120" />
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

#### How It Works (Mathematical Proof)

Claude's quota system operates on a **rolling 5-hour window** that only starts when you send your first message. Understanding this mechanism is key to optimizing wait times.

**The Core Problem:**

When you hit your quota limit, you must wait for the 5-hour window to reset. The wait time depends on *when* the window started relative to when you hit the limit.

**Real-World Scenario:**

```
Without Smart Quota Refresh:
┌─────────────────────────────────────────────────────────────┐
│ 10:00 AM: Idle (no active window, "null state")            │
│ 12:00 PM: You start using Claude → Window STARTS            │
│ 2:00 PM:  You hit quota limit (used for 2 hours)           │
│ 2:00 PM - 5:00 PM: WAITING (3 hours)                       │
│ 5:00 PM:  Window resets (12:00 PM + 5h)                    │
└─────────────────────────────────────────────────────────────┘

Wait Time = 5h - 2h = 3 hours
```

```
With Smart Quota Refresh:
┌─────────────────────────────────────────────────────────────┐
│ 10:00 AM: Auto-refresh triggers → Window STARTS             │
│           (~15 tokens spent)                                 │
│ 12:00 PM: You start using Claude (window already 2h old)   │
│ 2:00 PM:  You hit quota limit (used for 2 hours)           │
│ 2:00 PM - 3:00 PM: WAITING (1 hour)                        │
│ 3:00 PM:  Window resets (10:00 AM + 5h)                    │
└─────────────────────────────────────────────────────────────┘

Wait Time = 5h - 2h - 2h = 1 hour
Time Saved = 3h - 1h = 2 hours (66.7% reduction)
```

**The Mathematical Formula:**

Let:

- `W` = Window duration (5 hours)
- `L` = Time to hit quota limit after you start using Claude
- `Δ` = Lead time (hours between auto-refresh and when you actually use Claude)

```
Without Smart Refresh:
  Wait Time = W - L

With Smart Refresh:
  Wait Time = W - L - Δ

Time Saved:
  Savings = Δ
  Percentage Reduction = (Δ / (W - L)) × 100%
```

**Example Calculation:**

For W=5h, L=2h, Δ=2h:

- **Without:** 5 - 2 = 3 hours wait
- **With:** 5 - 2 - 2 = 1 hour wait
- **Savings:** 2 hours (66.7% reduction)

**Optimization Visualization:**

<p align="center">
  <img width="4170" height="2973" alt="claude_quota_optimization" src="https://github.com/user-attachments/assets/cd911223-42c7-44a6-801c-5c935d8c8391" />
</p>

*The graph shows how wait time decreases as the auto-start lead time (Δ) increases. Maximum optimization occurs when Δ = W - L, reducing wait time to zero.*

**Key Insights:**

1. **Cost:** ~15 tokens per auto-refresh trigger
2. **Benefit:** Reduces wait time by up to 100% (when Δ = W - L)
3. **ROI:** In the example above, spending 15 tokens saves 2 hours of waiting
4. **Best Practice:** Enable Smart Quota Refresh if you use Claude sporadically rather than continuously

**When It Helps Most:**

- You use Claude in bursts (e.g., morning and evening sessions)
- You frequently hit quota limits
- You want to minimize downtime between sessions

**When It's Less Useful:**

- You use Claude continuously throughout the day
- You rarely hit quota limits
- Your usage patterns already align with 5-hour intervals

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
