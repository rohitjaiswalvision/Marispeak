# Quick Test Checklist ✅

## What Changed
Fixed PTT audio playback and talk button on lock screen by:
- Setting active remote participant to keep session alive
- Adding group ID persistence for replying
- Adding debug logs to track audio playback

## How to Test

### 1️⃣ Rebuild the App
```bash
cd /Users/pc/Downloads/agora_ptt
flutter run --release
```
Let it install and launch on your iPhone.

### 2️⃣ Test Audio Reception

**Steps**:
1. Press home button (don't kill app)
2. Lock the iPhone  
3. From another device, send a PTT message
4. **Expected**: Audio plays loud from speaker

**Success Indicators**:
- 🔊 You hear the audio clearly
- 📱 Screen wakes up
- 🎛️ You might see a small PTT UI overlay

### 3️⃣ Test Talk Button

**Steps**:
1. While audio is playing or just after it ends
2. Look for talk button (lock screen or Control Center)
3. Press and hold the button
4. Speak your message
5. Release the button

**Success Indicators**:
- 🎙️ You can record
- 📤 Other device receives your reply
- ✅ Message sends successfully

### 4️⃣ Test Killed App (Most Important!)

**Steps**:
1. **Force kill** the app (swipe up from app switcher)
2. Lock the iPhone
3. From another device, send PTT message
4. **Expected**: App wakes, audio plays, talk button available

**This is the critical test!** The whole fix is designed for this scenario.

## What to Look For in Xcode Console

### ✅ Good Logs (Success)
```
📨 PTT Push Received: ...
🔊 PTT push — will play audio and show system UI
🎙️ PTT Audio Session Activated
🔊 NativePTTPlayer: Received XXXX bytes of audio
📦 Queue size: 1, isPlaying: false, sessionActive: true
✅ NativePTTPlayer: Audio chunk playing at full volume on speaker
⏱️ Audio queue empty, waiting 3.5s before ending session...
```

### ❌ Bad Logs (Problem)
```
🎙️ PTT Audio Session Activated
🎙️ Left PTT Channel           ← Bad! Too early!
🎙️ PTT Audio Session Deactivated
```

### 🎙️ Talk Button Logs (When You Press It)
```
🎙️ Began Transmitting
🎙️ NativePTTPlayer: Started recording chunk
📤 NativePTTPlayer: Sent audio chunk (XXXX bytes)
🎙️ Ended Transmitting
```

### ❌ Error to Watch For
```
❌ Cannot transmit: No groupId available!
```
If you see this, the group ID wasn't stored properly.

## Quick Fixes

### If Audio Doesn't Play
- Check that you're testing with **lock screen** (not just background)
- Verify iPhone is **not on silent mode**
- Check **volume** is turned up
- Look for error logs in Xcode

### If Talk Button Doesn't Appear
The system PTT UI is subtle. Check:
- **Lock screen controls** (swipe up)
- **Control Center** (swipe down from top right)
- **Dynamic Island** (iPhone 14 Pro/Pro Max)

Sometimes iOS doesn't show UI if:
- Notification settings block it
- Focus mode is active
- Low power mode is on

### If Talk Button Doesn't Send
1. Check Xcode logs for `❌ Cannot transmit: No groupId available!`
2. Verify the push payload contains `groupId`
3. Check that WebSocket server is running and reachable

## Server-Side Check

Make sure your PTT server is running:
```bash
# Check if server is running
lsof -i :3010

# Or start it if needed
cd /path/to/server
node ptt-server.js
```

Your logs show the server is running at:
- **WebSocket**: `ws://192.168.3.192:3010`
- **Production**: `wss://ptt.visionvivante.in`

## Expected Flow (End-to-End)

1. User A sends message → Server receives
2. Server sees User B is offline → Sends VoIP push to User B
3. User B's phone wakes up → PTT framework activates
4. App connects to WebSocket → Receives audio chunks
5. Audio plays loudly → User B hears message
6. PTT UI shows talk button → User B can reply
7. User B presses talk button → `didBeginTransmittingFrom` fires
8. App records and sends → User A receives reply

## One-Line Status Check

After testing, you should be able to say:

✅ "I can receive PTT audio on lock screen and reply using the talk button"

If not, share:
1. Which step failed (audio reception or talk button)
2. The Xcode console logs
3. Whether app was backgrounded or killed

## Files Changed
- `ios/Runner/AppDelegate.swift`

## Documentation
- `FINAL_PTT_FIX_SUMMARY.md` - Complete technical details
- `PTT_FRAMEWORK_AUDIO_FIX.md` - Audio playback fix explanation
- `TALK_BUTTON_IMPLEMENTATION_GUIDE.md` - Talk button implementation options
- `CALLKIT_TALK_BUTTON_FIX.md` - Original CallKit approach (for iOS < 16)

Good luck! 🚀
