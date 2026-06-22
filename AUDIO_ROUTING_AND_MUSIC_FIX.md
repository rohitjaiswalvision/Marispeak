# 🎧 Audio Routing & Background Music Fix

## Issues to Fix

### Issue 1: Earbuds Not Working
**Problem**: Audio always plays from iPhone speaker, even when earbuds/headphones connected
**Expected**: Audio should play through earbuds when connected

### Issue 2: Background Music Doesn't Resume
**Problem**: Spotify/Apple Music stops playing after PTT and doesn't resume
**Expected**: Music should pause during PTT, then automatically resume

---

## Root Causes

### Issue 1: Force Speaker Override

Your audio session is using:
```swift
options: [.defaultToSpeaker, .allowBluetooth]
```

**Problem**: `.defaultToSpeaker` **forces** audio to iPhone speaker, ignoring connected earbuds!

**What it means**:
- `.defaultToSpeaker` = "ALWAYS use speaker"
- `.allowBluetooth` = "Allow Bluetooth" (but defaultToSpeaker overrides this)
- Result: Speaker wins, earbuds ignored

### Issue 2: Missing Music Resumption

Your code deactivates the audio session but doesn't tell iOS to resume other audio:
```swift
// ❌ OLD CODE:
try session.setActive(false)  // Stops your audio, but doesn't resume music
```

**What's missing**: The `.notifyOthersOnDeactivation` option that tells iOS "I'm done, resume other apps' audio"

---

## The Fixes

### Fix 1: Smart Audio Routing (Earbuds First, Speaker Fallback)

**Change audio session options**:

```swift
// ✅ NEW CODE:
options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
```

**What this does**:
- `.mixWithOthers` = Allow background music to play simultaneously (paused during PTT)
- `.allowBluetooth` = Allow Bluetooth headphones (HandsFreeProfile - calls)
- `.allowBluetoothA2DP` = Allow Bluetooth headphones (A2DP - high quality audio)
- **NO** `.defaultToSpeaker` = iOS will route to connected device automatically:
  - Earbuds connected → Audio to earbuds ✅
  - No earbuds → Audio to speaker ✅

### Fix 2: Resume Background Music After PTT

**Change session deactivation**:

```swift
// ✅ NEW CODE:
try session.setActive(false, options: .notifyOthersOnDeactivation)
```

**What this does**:
- `.notifyOthersOnDeactivation` = Tell iOS "I'm done, resume Spotify/Music"
- iOS automatically resumes any paused audio (Spotify, Apple Music, podcasts, etc.)

---

## Implementation

### File 1: `lib/screens/ptt/websocket_ptt_controller.dart`

**Line ~81-97**: Change Flutter audio session configuration:

```dart
await session.configure(AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
  // ✅ FIX: Remove .defaultToSpeaker so earbuds work!
  avAudioSessionCategoryOptions:
      AVAudioSessionCategoryOptions.mixWithOthers |
      AVAudioSessionCategoryOptions.allowBluetooth |
      AVAudioSessionCategoryOptions.allowBluetoothA2DP,  // ✅ High-quality Bluetooth
  avAudioSessionMode: AVAudioSessionMode.defaultMode,
  avAudioSessionRouteSharingPolicy:
      AVAudioSessionRouteSharingPolicy.defaultPolicy,
  avAudioSessionSetActiveOptions:
      AVAudioSessionSetActiveOptions.none,
  androidAudioAttributes: const AndroidAudioAttributes(
    contentType: AndroidAudioContentType.music,
    flags: AndroidAudioFlags.none,
    usage: AndroidAudioUsage.media,
  ),
  androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
  androidWillPauseWhenDucked: false,
));
```

**Line ~310-320**: Fix session deactivation to resume music:

```dart
// ✅ FIX: Add .notifyOthersOnDeactivation to resume background music
final session = await AudioSession.instance;
try {
  await session.setActive(false, 
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation
  );
  debugPrint("✅ Session deactivated - background music will resume");
} catch (e) {
  debugPrint("⚠️ Session deactivation failed: $e");
}
```

### File 2: `ios/Runner/AppDelegate.swift`

**Line ~162**: Fix Flutter playback audio session (remove defaultToSpeaker):

```swift
// ✅ FIX: Remove .defaultToSpeaker so earbuds work
try session.setCategory(.playAndRecord, mode: .default, options: [
  .duckOthers, 
  .allowBluetooth, 
  .allowBluetoothA2DP,  // ✅ High-quality Bluetooth
  .mixWithOthers
])
```

**Line ~536-538**: Fix native session deactivation:

```swift
// ✅ FIX: Add .notifyOthersOnDeactivation to resume background music
try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
print("🎧 Audio session deactivated - Music/Bluetooth resumed")
```

**Line ~820-824**: Fix PTT delivery audio session:

```swift
private func activateAudioSessionForPTT() {
  do {
    let session = AVAudioSession.sharedInstance()
    // ✅ FIX: Use .playback with .mixWithOthers instead of .defaultToSpeaker
    try session.setCategory(.playback, options: [.mixWithOthers, .duckOthers, .allowBluetooth, .allowBluetoothA2DP])
    try session.setActive(true)
    // ❌ REMOVED: overrideOutputAudioPort(.speaker) - let iOS choose device
    print("✅ AVAudioSession activated for PTT - smart audio routing enabled")
  } catch {
    print("⚠️ Failed to activate audio session for PTT: \(error)")
  }
}
```

**Line ~857-872**: Remove force speaker override:

```swift
private func forceSpeakerAfterDisable() {
  // ✅ FIX: Removed! This was forcing speaker even with earbuds connected
  // Let iOS handle audio routing automatically based on connected devices
  print("🎧 Audio routing: Auto (earbuds first, speaker fallback)")
}
```

---

## Expected Behavior After Fix

### Test 1: Earbuds/Headphones

**Without earbuds**:
```
PTT audio arrives → Plays from iPhone speaker ✅
```

**With earbuds connected**:
```
PTT audio arrives → Plays through earbuds ✅
```

**With Bluetooth headphones**:
```
PTT audio arrives → Plays through Bluetooth headphones ✅
```

**With car Bluetooth**:
```
PTT audio arrives → Plays through car speakers ✅
```

### Test 2: Background Music

**Scenario**: User listening to Spotify

**Before fix**:
```
1. Spotify playing 🎵
2. PTT audio arrives
3. Spotify stops 🔇
4. PTT plays
5. PTT ends
6. ❌ Spotify stays stopped (user must manually restart)
```

**After fix**:
```
1. Spotify playing 🎵
2. PTT audio arrives
3. Spotify pauses (volume lowers)
4. PTT plays
5. PTT ends
6. ✅ Spotify automatically resumes 🎵
```

---

## Technical Details

### How iOS Audio Routing Works

iOS automatically chooses audio output in this priority order:
1. **Wired headphones** (3.5mm jack or Lightning)
2. **Bluetooth A2DP** (wireless headphones/earbuds)
3. **Bluetooth HFP** (hands-free profile for calls)
4. **Speaker** (built-in iPhone speaker)

**With `.defaultToSpeaker`**: iOS ignores 1-3 and always uses 4 ❌
**Without `.defaultToSpeaker`**: iOS follows the priority list ✅

### How `.notifyOthersOnDeactivation` Works

When you call `setActive(false, options: .notifyOthersOnDeactivation)`:

1. Your app tells iOS: "I'm done with audio"
2. iOS sends notification to **all other audio apps**
3. Apps that were paused (Spotify, Music, etc.) receive notification
4. They automatically resume playback

**Without this option**: iOS doesn't notify other apps, so they stay paused ❌

---

## Client Feedback This Fixes

From your client's email:

> "the app completely takes over the Bluetooth system and will not let you listen to any music"

**Fixed by**:
- Removing `.defaultToSpeaker` (allows earbuds/Bluetooth to work)
- Adding `.mixWithOthers` (doesn't hijack audio system)
- Adding `.notifyOthersOnDeactivation` (resumes music after PTT)

---

## Testing Instructions

### Test 1: Wired Earbuds
```
1. Plug in wired earbuds/headphones
2. Receive PTT message
3. ✅ Audio should play through earbuds (NOT speaker)
```

### Test 2: Bluetooth Headphones
```
1. Connect AirPods/Bluetooth headphones
2. Receive PTT message
3. ✅ Audio should play through headphones (NOT speaker)
```

### Test 3: Car Bluetooth
```
1. Connect to car Bluetooth
2. Receive PTT message
3. ✅ Audio should play through car speakers (NOT phone speaker)
```

### Test 4: Background Music (Spotify)
```
1. Start playing Spotify
2. Keep Spotify playing in background
3. Receive PTT message
4. ✅ PTT plays, Spotify volume lowers/pauses
5. PTT ends
6. ✅ Spotify automatically resumes
```

### Test 5: Background Music (Apple Music)
```
1. Start playing Apple Music
2. Keep music playing in background
3. Receive PTT message
4. ✅ PTT plays, Music pauses
5. PTT ends
6. ✅ Music automatically resumes
```

### Test 6: Podcast
```
1. Start playing podcast app
2. Receive PTT message
3. ✅ PTT plays, podcast pauses
4. PTT ends
5. ✅ Podcast automatically resumes from same position
```

---

## Important Notes

### Volume Behavior

**With `.duckOthers`**:
- Background music volume lowers to ~20% during PTT
- Music continues playing quietly
- After PTT, music volume returns to 100%

**With `.mixWithOthers`**:
- Background music completely pauses during PTT
- After PTT, music resumes at full volume

**Recommendation**: Use `.duckOthers` for better UX (music doesn't fully stop)

### Bluetooth A2DP vs HFP

**A2DP** (Advanced Audio Distribution Profile):
- High-quality stereo audio
- Used for music/media playback
- Example: AirPods playing Spotify

**HFP** (Hands-Free Profile):
- Lower quality mono audio
- Used for phone calls
- Example: Car Bluetooth for calls

**Your fix enables BOTH**:
- `.allowBluetooth` = HFP (calls)
- `.allowBluetoothA2DP` = A2DP (high-quality audio)

---

## Summary

**Changes Made**:
1. ✅ Removed `.defaultToSpeaker` → Earbuds now work
2. ✅ Added `.allowBluetoothA2DP` → High-quality Bluetooth audio
3. ✅ Added `.notifyOthersOnDeactivation` → Background music resumes
4. ✅ Removed `overrideOutputAudioPort(.speaker)` → Auto routing works
5. ✅ Changed to `.mixWithOthers` → Doesn't hijack audio system

**Result**: 
- PTT works with earbuds/headphones ✅
- Background music resumes after PTT ✅
- No more Bluetooth hijacking ✅
- Client happy ✅

**Deploy this fix and test with client's car/boat Bluetooth!** 🎧🚗⛵
