# 🔧 Fix: 2nd & 3rd Messages Not Sending

## Issue
User reported: "first audio send button other 2 i send that i didinot hear"

**Pattern**:
- Message 1: Works ✅
- Message 2: Fails ❌  
- Message 3: Fails ❌

## Root Cause

After the first recording session, the recorder state was not being fully reset. When the user pressed PTT a 2nd time:

1. `_chunkTimer` from previous session still exists (not fully canceled)
2. `_recorder` might still be in "stopping" state
3. `_filePath` still points to old file
4. New recording starts with corrupted state
5. **Result**: No audio sent for 2nd, 3rd messages

## The Fix

Added **full state reset** before starting new recording:

```dart
Future<void> startRecording() async {
  if (isRecording) {
    debugPrint("⚠️ Already recording, ignoring startRecording() call");
    return;
  }
  
  // ✅ FIX: Clean up any leftover state from previous recording
  _chunkTimer?.cancel();
  _chunkTimer = null;
  _filePath = null;
  
  // ✅ FIX: Ensure recorder is fully stopped before starting new recording
  final isCurrentlyRecording = await _recorder.isRecording();
  if (isCurrentlyRecording) {
    debugPrint("⚠️ Recorder still active from previous session, stopping it first...");
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint("⚠️ Error stopping previous recording: $e");
    }
    // Wait for recorder to fully release resources
    await Future.delayed(const Duration(milliseconds: 200));
  }
  
  isRecording = true;
  debugPrint("🎙️ Starting recording with real-time chunking...");
  
  // ... rest of recording setup
}
```

**What this does**:
1. Cancels any leftover timer from previous session
2. Clears old file path
3. **Checks if recorder is still active** (Android issue!)
4. Stops previous recorder if needed
5. Waits 200ms for cleanup
6. Starts fresh recording

## Testing

### Quick Test: 5 Consecutive Messages

1. **Press PTT** → Hold 2 seconds → Release
2. **Wait 1 second**
3. **Press PTT** → Hold 2 seconds → Release  ← Should work now!
4. **Wait 1 second**
5. **Press PTT** → Hold 2 seconds → Release  ← Should work now!
6. **Wait 1 second**
7. **Press PTT** → Hold 2 seconds → Release  ← Should work now!
8. **Wait 1 second**
9. **Press PTT** → Hold 2 seconds → Release  ← Should work now!

**Expected**: Other side hears ALL 5 messages ✅

### Debug Logs to Check

**For EACH message, you should see**:

```
flutter: 🎙️ Starting recording with real-time chunking...
flutter: ⏱️ Starting chunk timer - will send audio every 1.5s
flutter: 🎬 Starting new chunk: tx_1782113900749.m4a
flutter: ✅ Recorder started successfully
[hold for 2 seconds - timer fires at 1.5s]
flutter: ⏰ Chunk timer fired - sending current chunk...
flutter: 📤 Flushing chunk: tx_1782113900749.m4a
flutter: 📤 Sending audio with channelUUID: 201D1D87...
flutter: ✅ Chunk sent successfully
flutter: 🎬 Starting new chunk: tx_1782113902249.m4a
[release button]
flutter: 🛑 Stopping recording...
flutter: ⏹️ Recording stopped, canceling chunk timer
flutter: 📤 Sending final chunk: tx_1782113902249.m4a
flutter: ✅ Recording stopped and final chunk sent
```

**For 2nd message, if you see**:
```
flutter: ⚠️ Recorder still active from previous session, stopping it first...
```

This means the fix is working - it detected leftover state and cleaned it up!

## Android-Specific Issue

The Android MPEG4Writer error happens when:
```
E/MPEG4Writer(11663): Stop() called but track is not started or stopped
```

This means Android's media recorder is in a bad state. Our fix:
1. Checks `await _recorder.isRecording()` before stopping
2. Waits 200ms for recorder to fully release
3. Clears all state before starting new recording

## If Still Not Working

### Check 1: Is Recorder State Being Reset?

Look for this log when pressing PTT the 2nd time:
```
flutter: ⚠️ Recorder still active from previous session, stopping it first...
```

- ✅ **If you see this**: Fix is working, it's cleaning up old state
- ❌ **If you don't see this**: Recorder was clean, issue is elsewhere

### Check 2: Are Chunks Being Sent?

For EVERY message, look for:
```
flutter: 📤 Sending audio with channelUUID: ...
```

- ✅ **If you see this for all messages**: Chunks are being sent
- ❌ **If missing for 2nd/3rd**: WebSocket disconnected or `_sendFile()` failing

### Check 3: Server Receiving Chunks?

```bash
pm2 logs ptt_vision --lines 100
```

Should see for EVERY message:
```
55|ptt_vision  | 📤 Audio chunk received from ajaw9LhcwUSp5tyoVXorVYV8N473
55|ptt_vision  | 📡 Broadcasting to group ajaw9LhcwUSp5tyoVXorVYV8N473_bvzrZKSKA4RVEXFjJaEHfIWUo2O2
```

- ✅ **If you see for all messages**: Server is receiving correctly
- ❌ **If missing for 2nd/3rd**: Chunks not reaching server

## Deploy

```bash
# Hot restart is enough for this fix (no native code changes)
flutter run --release
```

Or press `R` in your running debug session to hot restart.

## Expected Result

**Before Fix**:
```
Message 1: ✅ Works
Message 2: ❌ Silence
Message 3: ❌ Silence
Message 4: ❌ Silence
```

**After Fix**:
```
Message 1: ✅ Works
Message 2: ✅ Works
Message 3: ✅ Works
Message 4: ✅ Works
Message 5: ✅ Works
...
Message 100: ✅ Works
```

**Perfect walkie-talkie, send as many messages as you want!** 🎙️📡✅
