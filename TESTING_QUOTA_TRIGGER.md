# Testing Guide: Quota Period Trigger Feature

This guide will help you test the new quota period trigger feature in ClaudeMeter.

## Overview

The quota period trigger feature allows ClaudeMeter to automatically start a new 5-hour quota period by sending a minimal message (~10-20 tokens) when your current quota period has expired (null state).

## Features Implemented

1. **Auto-Trigger Toggle**: Enable/disable automatic quota period triggering in Settings
2. **Manual Trigger**: Menu item to manually start a new quota period at any time
3. **Null State Detection**: Automatically detects when quota is in null state (no active 5-hour period)
4. **Comprehensive Logging**: All API calls and events are logged for debugging

## Building the App

### Option 1: Quick Run (Build + Run)
```bash
./run.sh
```

### Option 2: Build Only
```bash
./Scripts/build.sh
# Then run manually:
./.build/release/ClaudeMeter
```

### Option 3: Manual Build
```bash
swift build -c release
./.build/release/ClaudeMeter
```

## Viewing Logs

Logs are critical for testing this feature. Here's how to access them:

### Method 1: From the App
1. Click the ClaudeMeter icon in the menu bar
2. Select "View Logs"
3. This opens the log directory in Finder

### Method 2: Terminal (Live Monitoring)
```bash
# Watch logs in real-time
tail -f ~/.config/claude-meter/logs/claudemeter-*.log

# View most recent log file
ls -t ~/.config/claude-meter/logs/ | head -1 | xargs -I {} cat ~/.config/claude-meter/logs/{}

# Filter for quota-related logs
tail -f ~/.config/claude-meter/logs/claudemeter-*.log | grep -i quota
```

### Method 3: Direct File Access
```bash
# Open log directory
open ~/.config/claude-meter/logs/

# View latest log
cat ~/.config/claude-meter/logs/claudemeter-*.log | tail -100
```

## Testing the Feature

### Test 1: Enable Auto-Trigger

1. **Build and run the app**
   ```bash
   ./run.sh
   ```

2. **Open Settings**
   - Click the ClaudeMeter menu bar icon
   - Select "Settings..." (or press Cmd+,)

3. **Enable Auto-Trigger**
   - Scroll down to "Quota Optimization" section
   - Toggle ON "Auto-trigger quota period"
   - Click "Save"

4. **Check the logs**
   ```bash
   tail -20 ~/.config/claude-meter/logs/claudemeter-*.log
   ```

   You should see:
   ```
   [INFO] Settings saved successfully (auto-trigger: true)
   ```

### Test 2: Manual Trigger (Immediate Test)

This is the easiest way to test the feature without waiting for quota to expire.

1. **Run the app** (if not already running)

2. **Open the menu bar**
   - Click the ClaudeMeter icon

3. **Click "Start New Quota Period"**
   - This will immediately trigger a new quota period

4. **Monitor logs in real-time**
   ```bash
   tail -f ~/.config/claude-meter/logs/claudemeter-*.log
   ```

5. **Expected log output:**
   ```
   [INFO] Manual quota trigger requested
   [INFO] Starting quota period trigger sequence
   [DEBUG] Creating new conversation at: https://claude.ai/api/organizations/{org}/chat_conversations
   [DEBUG] Create conversation response status: 200
   [INFO] Conversation created with UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   [DEBUG] Sending minimal message to conversation: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   [DEBUG] Sending payload with timezone: America/New_York
   [DEBUG] Send message response status: 200
   [DEBUG] Parsing SSE response (XXXX characters)
   [DEBUG] Found message_limit event
   [DEBUG] message_limit JSON: {"type":"message_limit","message_limit":...
   [DEBUG] Parsed resets_at: 1762606800
   [INFO] Successfully extracted resets_at timestamp: 1762606800
   [INFO] Quota period trigger complete. New period resets at: 1762606800
   [INFO] New quota period started, resets at: 1762606800
   ```

6. **Check for success notification**
   - You should see a system notification: "Quota Period Started - New 5-hour quota period activated (used ~10-20 tokens)"

### Test 3: Auto-Trigger on Null State

This test requires waiting for your quota to expire (5+ hours of inactivity).

1. **Enable auto-trigger** (see Test 1)

2. **Wait for quota to expire**
   - Don't use Claude for 5+ hours
   - Or use the Claude web interface to exhaust your quota

3. **Open the app or wait for periodic refresh**
   - The app refreshes every 60 seconds
   - Or click the menu bar icon to force refresh

4. **Monitor logs**
   ```bash
   tail -f ~/.config/claude-meter/logs/claudemeter-*.log | grep -E "(Detected null|quota)"
   ```

5. **Expected behavior:**
   - When null state is detected, logs will show:
   ```
   [DEBUG] Fetching usage data
   [DEBUG] API response status: 200
   [INFO] Detected null quota state with auto-trigger enabled
   [INFO] Triggering new quota period
   [INFO] Starting quota period trigger sequence
   ...
   [INFO] New quota period started, resets at: XXXXXXXXXX
   ```

### Test 4: Verify Claude Web Interface

After triggering a quota period (manually or automatically):

1. **Open Claude in your browser**
   - Go to https://claude.ai

2. **Check conversations**
   - You should see a new conversation with a single "hi" message
   - This is the minimal message sent to trigger the quota

3. **Optional: Delete the conversation**
   - You can safely delete this conversation if you want
   - It won't affect the triggered quota period

## Debugging

### Common Log Patterns to Look For

#### Success Pattern
```
[INFO] Starting quota period trigger sequence
[INFO] Conversation created with UUID: ...
[INFO] Successfully extracted resets_at timestamp: ...
[INFO] Quota period trigger complete
```

#### Authentication Error
```
[ERROR] API error: HTTP 401
[WARNING] Authentication error detected (HTTP 401). Credentials may have expired.
```
**Solution**: Re-run auto-detection or manually update credentials in Settings

#### Parse Error
```
[ERROR] No message_limit event found in SSE response
[ERROR] Parse error: message_limit event not found in response
```
**Solution**: Check that Claude API is responding correctly. This could indicate an API change.

#### Network Error
```
[ERROR] Error fetching usage: The Internet connection appears to be offline
```
**Solution**: Check your internet connection

### Enable Debug Logging

The app already logs at DEBUG level by default. To filter for specific events:

```bash
# Show only quota-related logs
tail -f ~/.config/claude-meter/logs/claudemeter-*.log | grep -i "quota"

# Show only API calls
tail -f ~/.config/claude-meter/logs/claudemeter-*.log | grep -i "API"

# Show only errors
tail -f ~/.config/claude-meter/logs/claudemeter-*.log | grep "\[ERROR\]"

# Show conversation creation
tail -f ~/.config/claude-meter/logs/claudemeter-*.log | grep -i "conversation"

# Show SSE parsing
tail -f ~/.config/claude-meter/logs/claudemeter-*.log | grep -i "SSE\|message_limit"
```

## Verification Checklist

After running tests, verify:

- [ ] Settings toggle appears in Settings window
- [ ] Toggle state persists after saving and reopening Settings
- [ ] "Start New Quota Period" menu item appears in menu bar
- [ ] Manual trigger creates conversation and sends message
- [ ] Logs show complete sequence from start to finish
- [ ] Notification appears after successful trigger
- [ ] New conversation appears in Claude web interface
- [ ] Usage data refreshes after trigger
- [ ] Auto-trigger works when quota is in null state
- [ ] No errors in logs (except expected auth errors if credentials expire)

## Advanced Testing

### Test Network Resilience

1. **Disconnect from internet**
2. **Click "Start New Quota Period"**
3. **Check logs for proper error handling**
   ```bash
   tail -20 ~/.config/claude-meter/logs/claudemeter-*.log
   ```

### Test with Invalid Credentials

1. **Open Settings**
2. **Modify session key slightly (change one character)**
3. **Save and try manual trigger**
4. **Expected**: Should see HTTP 401/403 error in logs

### Monitor API Requests

Use a network proxy like Charles Proxy or mitmproxy to inspect:
- Request headers
- Request body
- Response format
- SSE event stream

## Troubleshooting

### App doesn't start
```bash
# Check build errors
swift build -c release

# Check if process is already running
ps aux | grep ClaudeMeter
```

### No logs appearing
```bash
# Check if log directory exists
ls -la ~/.config/claude-meter/logs/

# Check permissions
ls -la ~/.config/claude-meter/
```

### Feature not working
1. Check logs for errors
2. Verify credentials are valid (try manual refresh first)
3. Check internet connection
4. Verify you're using the correct branch
5. Rebuild the app from scratch

## Expected Token Usage

Each quota trigger consumes approximately **10-20 tokens**:
- Request: ~5-10 tokens ("hi" message)
- Response: ~5-10 tokens (minimal response)

This is significantly less than a typical conversation, making it ideal for maintaining an active quota period.

## Next Steps

After successful testing:
1. Monitor the app over several days
2. Check if auto-trigger works reliably
3. Verify token usage in Claude settings
4. Report any issues or unexpected behavior

## Support

If you encounter issues:
1. Collect the log file from `~/.config/claude-meter/logs/`
2. Note the exact steps to reproduce
3. Check for any error messages or alerts
4. Verify your Claude credentials are valid

---

**Happy Testing!** 🚀
