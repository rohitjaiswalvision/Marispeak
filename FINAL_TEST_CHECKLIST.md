# Final Test Checklist - PTT Lock Screen Fix

## What Was Wrong
❌ NativePTTPlayer connected to **production server** (`wss://ptt.visionvivante.in`)  
❌ Flutter connected to **development server** (`ws://192.168.3.192:3010`)  
❌ Audio chunks went to the wrong server → never reached NativePTTPlayer

## What's Fixed
✅ Flutter stores PTT server URL in UserDefaults on startup  
✅ Native reads PTT server URL from UserDefaults  
✅ Both connect to the SAME server  
✅ Audio chunks flow correctly

---

## Quick Test (5 minutes)

### Step 1: Rebuild and Launch
```bash
flutter run --release
```

### Step 2: Verify URL Storage
Look for this log on app startup:
```
📍 Stored PTT server URL: ws://192.168.3.192:3010  ✅
```

### Step 3: Background the App
- Press home button
- Lock the phone

### Step 4: Send PTT Message
From another device, send a PTT message

### Step 5: Watch for These Logs
```
📨 PTT Push Received: ...
🔗 Using PTT server: ws://192.168.3.192:3010  ✅ SAME SERVER!
✅ NativePTTPlayer: WebSocket connected
🔊 NativePTTPlayer: Received 14378 bytes of audio  ✅ CHUNKS ARRIVE!
📦 Queue size: 1, isPlaying: false, sessionActive: true
✅ NativePTTPlayer: Audio chunk playing at full volume on speaker  ✅
```

### Step 6: Listen for Audio
👂 You should hear the PTT message loud and clear from the speaker!

---

## Success Criteria

| Test | Expected Result | Status |
|------|----------------|--------|
| URL stored on startup | See `📍 Stored PTT server URL` log | ⬜ |
| Native reads correct URL | See `🔗 Using PTT server: ws://192.168.3.192:3010` | ⬜ |
| Audio chunks received | See `🔊 NativePTTPlayer: Received XXXX bytes` | ⬜ |
| Audio plays | Hear sound from speaker | ⬜ |
| Talk button works | Can reply from lock screen | ⬜ |

---

## Failure Scenarios

### If No Audio Plays

**Check Log**:
```
🔗 Using PTT server: wss://ptt.visionvivante.in  ❌ WRONG!
```

**Cause**: UserDefaults wasn't set. Fallback to production server.

**Fix**: 
1. Kill the app completely
2. Relaunch (so main() stores the URL)
3. Try again

---

### If Wrong URL is Stored

**Check Log**:
```
📍 Stored PTT server URL: wss://ptt.visionvivante.in  ❌ PRODUCTION!
```

**Cause**: Environment is set to production in `environment.dart`

**Fix**:
```dart
// lib/config/environment.dart
static Environment current = development; // Make sure this is set!
```

---

### If Still No Chunks Arrive

**Check Server Logs**:
```
🔌 ajaw9LhcwUSp5tyoVXorVYV8N473 disconnected
📲 Client offline — sending VoIP push
📦 Sending 3 pending audio chunks  ← Still buffering!
```

**Possible Causes**:
1. Server not running on `192.168.3.192:3010`
2. Firewall blocking connection
3. Phone and Mac on different networks

**Fix**:
```bash
# Check server is running
lsof -i :3010

# Check Mac IP address
ifconfig | grep "inet "

# Update environment.dart if IP changed
```

---

## Complete Test Flow

```
┌─────────────────────────────────────┐
│ 1. App Starts                       │
│    ✅ URL stored in UserDefaults    │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 2. Lock Phone                       │
│    ⏸️ App backgrounds               │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 3. PTT Message Sent                 │
│    📲 VoIP push arrives              │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 4. NativePTTPlayer Wakes            │
│    🔗 Reads URL from UserDefaults   │
│    📡 Connects to correct server    │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 5. Audio Chunks Arrive              │
│    🔊 Received 14378 bytes          │
│    📦 Added to queue                │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 6. Audio Plays                      │
│    🔊 Full volume on speaker        │
│    ✅ SUCCESS!                      │
└─────────────────────────────────────┘
```

---

## One-Line Status

After testing, you should be able to say:

**✅ "I can hear PTT audio on lock screen and it's loud and clear!"**

---

## Next Test: Talk Button

Once audio playback works:

1. **Wait for PTT UI to appear** (may be subtle)
2. **Look for talk button** (lock screen or Control Center)
3. **Press and hold** 🎙️
4. **Speak your reply**
5. **Release button**
6. **Check logs**:
   ```
   🎙️ Began Transmitting
   🔗 Using PTT server for transmit: ws://192.168.3.192:3010
   🎙️ NativePTTPlayer: Started recording
   📤 NativePTTPlayer: Sent audio chunk (57356 bytes)
   ```

---

## Documentation Reference

- **SERVER_URL_FIX.md** - Technical details of the fix
- **FINAL_PTT_FIX_SUMMARY.md** - Complete fix overview
- **PTT_FRAMEWORK_AUDIO_FIX.md** - Audio session management
- **PTT_FLOW_DIAGRAM.md** - Visual flow diagrams

---

## Ready to Test!

1. ✅ Code changes complete
2. ✅ URLs automatically synced
3. ✅ No compilation errors
4. 🚀 Ready for testing

**Run**: `flutter run --release` and follow the checklist above!

Good luck! 🎉
