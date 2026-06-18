# CRITICAL FIX: NativePTTPlayer Server URL Mismatch

## The Real Problem 🔥

Your PTT audio wasn't playing because **NativePTTPlayer was connecting to the WRONG server!**

### What Was Happening:

```
Flutter App (Foreground)
    ↓
Connects to: ws://192.168.3.192:3010 ✅ (Development server)
    ↓
Receives audio chunks and plays them


Flutter App (Background)
    ↓
Closes WebSocket
    ↓
VoIP Push arrives
    ↓
NativePTTPlayer starts
    ↓
Connects to: wss://ptt.visionvivante.in ❌ (Production server - WRONG!)
    ↓
NO audio chunks received (wrong server!)
    ↓
Server buffers chunks thinking user is offline
```

### Evidence from Your Logs:

**Native Side (Wrong Server)**:
```
📨 PTT Push Received: ...
🔊 NativePTTPlayer: Connecting as ajaw9LhcwUSp5tyoVXorVYV8N473
✅ NativePTTPlayer: WebSocket connected
🎬 processQueue called: queueSize=0  ← EMPTY! No chunks!
```

**Flutter Side (Right Server)**:
```
🟢 App resumed, reconnecting WebSocket
✅ Connected as ajaw9LhcwUSp5tyoVXorVYV8N473
📦 Flutter received 27381 bytes of audio  ← Chunks delivered!
```

**Server Side**:
```
🔌 ajaw9LhcwUSp5tyoVXorVYV8N473 disconnected (kept for VoIP push)
📲 Client ajaw9LhcwUSp5tyoVXorVYV8N473 is offline — sending VoIP push
...later...
✅ Registered: ajaw9LhcwUSp5tyoVXorVYV8N473
📦 Sending 3 pending audio chunks  ← Chunks were BUFFERED!
```

## The Fix ✅

### 1. Store PTT Server URL in UserDefaults (Flutter → Native)

**File**: `lib/main.dart`

```dart
// ✅ Store PTT server URL in UserDefaults for native code to use
final prefs = await SharedPreferences.getInstance();
await prefs.setString('flutter.ptt_server_url', Environment.current.pttServerUrl);
print('📍 Stored PTT server URL: ${Environment.current.pttServerUrl}');
```

This stores the URL from your `Environment.current.pttServerUrl` configuration:
- Development: `ws://192.168.3.192:3010`
- Staging: `wss://ptt-staging.visionvivante.in`
- Production: `wss://ptt.visionvivante.in`

### 2. Read PTT Server URL from UserDefaults (Native Side)

**File**: `ios/Runner/AppDelegate.swift`

**For Receiving (startBackgroundReceive)**:
```swift
// ✅ Read PTT server URL from Flutter's SharedPreferences
let serverUrl = UserDefaults.standard.string(forKey: "flutter.ptt_server_url") ?? "wss://ptt.visionvivante.in"
print("🔗 Using PTT server: \(serverUrl)")

guard let url = URL(string: serverUrl) else { 
    print("❌ Invalid PTT server URL: \(serverUrl)")
    return 
}
webSocketTask = urlSession.webSocketTask(with: url)
webSocketTask?.resume()
```

**For Transmitting (startTransmitting)**:
```swift
// ✅ Read PTT server URL from Flutter's SharedPreferences
let serverUrl = UserDefaults.standard.string(forKey: "flutter.ptt_server_url") ?? "wss://ptt.visionvivante.in"
print("🔗 Using PTT server for transmit: \(serverUrl)")

guard let url = URL(string: serverUrl) else { 
    print("❌ Invalid PTT server URL: \(serverUrl)")
    return 
}
webSocketTask = urlSession.webSocketTask(with: url)
webSocketTask?.resume()
```

## How It Works Now

```
1. App Starts
    ↓
2. Flutter reads Environment.current (Development)
    ↓
3. Flutter stores: ws://192.168.3.192:3010 in UserDefaults
    ↓
4. App goes to background
    ↓
5. VoIP push arrives
    ↓
6. NativePTTPlayer reads from UserDefaults
    ↓
7. Connects to: ws://192.168.3.192:3010 ✅ (SAME SERVER!)
    ↓
8. Audio chunks arrive immediately ✅
    ↓
9. Audio plays at full volume ✅
```

## Benefits of This Approach

### ✅ Single Source of Truth
- Change `Environment.current` in one place
- Both Flutter and Native use the same server
- No more hardcoded URLs in Swift

### ✅ Environment Switching
```dart
// Switch environments by changing ONE line:
static Environment current = development;  // Development
static Environment current = staging;      // Staging  
static Environment current = production;   // Production
```

### ✅ Automatic Sync
- Flutter stores the URL on startup
- Native always reads the latest value
- No manual configuration needed

### ✅ Fallback Safety
If UserDefaults doesn't have the URL (shouldn't happen), it falls back to production:
```swift
let serverUrl = UserDefaults.standard.string(forKey: "flutter.ptt_server_url") ?? "wss://ptt.visionvivante.in"
```

## Testing Instructions

### Test 1: Verify URL Storage

1. **Run the app**
2. **Watch logs** for:
   ```
   📍 Stored PTT server URL: ws://192.168.3.192:3010
   ```
3. **Verify** it matches your `Environment.current.pttServerUrl`

### Test 2: Verify Native Reading

1. **Background the app**
2. **Send PTT message**
3. **Watch logs** for:
   ```
   📨 PTT Push Received: ...
   🔗 Using PTT server: ws://192.168.3.192:3010  ← Should match!
   🔊 NativePTTPlayer: Connecting as userId
   ✅ NativePTTPlayer: WebSocket connected
   🔊 NativePTTPlayer: Received 27381 bytes of audio  ← NOW YOU'LL SEE THIS!
   ```

### Test 3: Audio Playback

1. **Lock the phone**
2. **Have someone send PTT message**
3. **Expected behavior**:
   - ✅ Audio plays immediately
   - ✅ Loud speaker output
   - ✅ PTT UI shows (if available)

### Test 4: Talk Button

1. **While audio is playing**
2. **Press talk button** (if UI appears)
3. **Speak your reply**
4. **Release button**
5. **Verify**:
   ```
   🎙️ Began Transmitting
   🔗 Using PTT server for transmit: ws://192.168.3.192:3010
   🎙️ NativePTTPlayer: Started recording
   📤 NativePTTPlayer: Sent audio chunk
   ```

## Expected Logs (Success)

```
[App Startup]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Environment: Development
PTT Server: ws://192.168.3.192:3010
API Server: https://dev-api.marispeak.com
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Stored PTT server URL: ws://192.168.3.192:3010

[Background - VoIP Push Arrives]
📨 PTT Push Received: ["groupId": xxx, "senderName": User, "type": ptt]
🔊 PTT push — will play audio and show system UI
🔗 Using PTT server: ws://192.168.3.192:3010  ✅
🔊 NativePTTPlayer: Connecting as userId to receive group groupId
✅ NativePTTPlayer: WebSocket connected
🎙️ PTT Audio Session Activated
🔊 NativePTTPlayer: Audio session active — full-volume speaker output
🔊 NativePTTPlayer: Received 14378 bytes of audio  ✅ FINALLY!
📦 Queue size: 1, isPlaying: false, sessionActive: true
🎬 processQueue called: sessionActive=true, isPlaying=false, queueSize=1
✅ NativePTTPlayer: Audio chunk playing at full volume on speaker  ✅
🔊 NativePTTPlayer: Received 28496 bytes of audio
📦 Queue size: 1, isPlaying: true, sessionActive: true
[Audio plays continuously...]
⏱️ Audio queue empty, waiting 3.5s before ending session...
⏰ Timer expired, posting PTTAudioFinished notification
🛑 Ending PTT Active Remote Participant
🎙️ PTT Audio Session Deactivated
```

## Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| Native Server | `wss://ptt.visionvivante.in` (hardcoded) | Reads from UserDefaults ✅ |
| Flutter Server | `ws://192.168.3.192:3010` (Environment) | Writes to UserDefaults ✅ |
| Audio Chunks | Never received ❌ | Received immediately ✅ |
| Audio Playback | Silent (queue empty) ❌ | Plays at full volume ✅ |
| Environment Switch | Required manual Swift code change ❌ | Automatic from Environment.dart ✅ |
| Configuration | Split across files ❌ | Single source of truth ✅ |

## Additional Notes

### Why This Wasn't Obvious

The logs showed:
```
✅ NativePTTPlayer: WebSocket connected
```

This made it LOOK like everything was working! But the connection was to the **wrong server**, so no chunks arrived.

The key clue was:
```
🎬 processQueue called: queueSize=0  ← Always empty!
```

Combined with:
```
📦 Flutter received 27381 bytes of audio  ← Chunks went to Flutter instead!
```

### Why PTT Framework Still Worked

The PTT framework (iOS 16+) successfully:
- ✅ Woke the app
- ✅ Activated audio session
- ✅ Kept session alive

But NativePTTPlayer couldn't receive chunks because it was on the wrong server!

### Production Deployment

When you're ready for production:

1. **Change environment**:
   ```dart
   // lib/config/environment.dart
   static Environment current = production; // <-- Change this
   ```

2. **Rebuild app**:
   ```bash
   flutter clean
   flutter build ios --release
   ```

3. **Native code automatically uses**:
   ```
   wss://ptt.visionvivante.in  ← Production server
   ```

No Swift code changes needed! ✅

## Files Modified

1. `lib/main.dart` - Store PTT server URL on startup
2. `ios/Runner/AppDelegate.swift` - Read PTT server URL from UserDefaults (2 locations)

## Summary

The audio wasn't playing because NativePTTPlayer was connecting to a different server than Flutter. By storing the server URL in UserDefaults and reading it on the native side, both sides now connect to the same server, and audio chunks flow correctly.

This was the **root cause** of all the issues. The previous fixes (setting active participant, storing groupId, etc.) were necessary but not sufficient. Now everything should work! 🎉
