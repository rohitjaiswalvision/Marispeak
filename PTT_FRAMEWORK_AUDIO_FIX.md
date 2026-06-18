# PTT Framework Audio Playback Fix

## Problem Analysis

Based on your logs, there are several issues:

### Issue 1: Audio Session Deactivates Immediately
```
🎙️ PTT Audio Session Activated
🎙️ Left PTT Channel           ❌ PTT Framework ends session too early
🎙️ PTT Audio Session Deactivated
🔌 NativePTTPlayer: Disconnected
```

**Root Cause**: The PTT Framework (iOS 16+) requires an **active remote participant** to be set. Without it, the framework assumes the transmission is over and immediately deactivates the audio session.

### Issue 2: No Audio Chunks Being Played
The logs show:
- ✅ WebSocket connects
- ✅ Audio chunks received (but no "Audio chunk playing" log)
- ❌ Audio queue never processes

**Root Cause**: Audio session is deactivated before chunks can be played, so `isAudioSessionActive = false` prevents `processQueue()` from running.

### Issue 3: Talk Button Not Working (When It Appears)
Even when CallKit/PTT UI shows, the talk button doesn't send because:
- Session ends too quickly
- No chance to press talk button before dismissal

## Solution Implemented

### 1. Set Active Remote Participant
When a PTT push arrives, we now set an active remote participant to keep the session alive:

```swift
func incomingPushResult(...) -> PTPushResult {
    let participant = PTParticipant(name: senderName, image: nil)
    channelManager.setActiveRemoteParticipant(participant, channelUUID: channelUUID) { error in
        if let error = error {
            print("❌ Failed to set active participant: \(error)")
        } else {
            print("✅ Set active remote participant: \(senderName)")
        }
    }
    ...
}
```

This tells the PTT framework: "Someone is talking, keep the session active."

### 2. Clear Remote Participant After Audio Finishes
```swift
// In PTTAudioFinished notification handler
if let manager = self.channelManager as? PTChannelManager, 
   let activeUUID = manager.activeChannelUUID {
    print("🛑 Ending PTT Active Remote Participant")
    manager.setActiveRemoteParticipant(nil, channelUUID: activeUUID, completionHandler: nil)
}
```

### 3. Added Debug Logging
To help diagnose issues:
- Log queue size, playing state, session state
- Log when processQueue is blocked
- Log when audio finishes and timer starts

## Testing Instructions

### Test 1: Background Audio Playback

1. **Open the app** and go to home screen
2. **Press home button** (don't kill the app)
3. **Lock the iPhone**
4. **Have someone send a PTT message**
5. **Expected behavior**:
   - No UI appears (silent background playback)
   - iPhone speakers should play the audio at full volume
   - You should hear the message clearly

**Watch for these logs:**
```
📨 PTT Push Received: ...
✅ Set active remote participant: User
🔊 NativePTTPlayer: Connecting as userId to receive group groupId
✅ NativePTTPlayer: WebSocket connected
🔊 NativePTTPlayer: Received XXXX bytes of audio
📦 Queue size: 1, isPlaying: false, sessionActive: true
🎬 processQueue called: sessionActive=true, isPlaying=false, queueSize=1
✅ NativePTTPlayer: Audio chunk playing at full volume on speaker
⏱️ Audio queue empty, waiting 3.5s before ending session...
⏰ Timer expired, posting PTTAudioFinished notification
🛑 Ending PTT Active Remote Participant
```

### Test 2: Killed App with Talk Button

1. **Force kill the app** (swipe up from app switcher)
2. **Have someone send a PTT message**
3. **Expected behavior**:
   - PTT framework wakes the app
   - Audio plays in background
   - **No UI should appear** (PTT framework doesn't show UI by default)

**Note**: The PTT framework (iOS 16+) does NOT show a CallKit-style UI automatically. To show a talk button UI, you need to either:
- Use the system PTT UI (requires additional configuration)
- Build a custom notification/UI

### Test 3: Talk Button (If UI Appears)

If you want the talk button to work from lock screen, you have two options:

#### Option A: Use System PTT UI (Recommended)
The PTT framework has a built-in UI that appears in Control Center and lock screen. To enable it, you need to:
1. Configure PTT channels properly
2. Use `requestBeginTransmitting(channelUUID:)` to start transmission
3. The system will show the PTT button in lock screen

#### Option B: Use CallKit for Killed App (Current Approach)
Currently, your app uses CallKit only when the app is force-killed. This shows an incoming call screen with answer/decline buttons, not a talk button.

To add a talk button to CallKit, you would need to use `CXStartCallAction` instead of incoming call, but this is not standard for PTT apps.

## What Logs to Watch

### Success Pattern:
```
📨 PTT Push Received
✅ Set active remote participant
🔊 NativePTTPlayer: Connecting
✅ NativePTTPlayer: WebSocket connected
🎙️ PTT Audio Session Activated
🔊 NativePTTPlayer: Received XXXX bytes
📦 Queue size: 1, isPlaying: false, sessionActive: true
✅ NativePTTPlayer: Audio chunk playing
[Audio plays on speaker]
⏱️ Audio queue empty, waiting 3.5s
⏰ Timer expired
🛑 Ending PTT Active Remote Participant
🎙️ PTT Audio Session Deactivated
```

### Failure Pattern (Old Behavior):
```
📨 PTT Push Received
🔊 PTT push — playing audio silently
🎙️ PTT Audio Session Activated
🎙️ Left PTT Channel              ❌ Too early!
🎙️ PTT Audio Session Deactivated ❌ Before audio plays!
🔌 NativePTTPlayer: Disconnected
```

## Additional Notes

### Why Audio Might Still Not Play

If audio still doesn't play after this fix, check:

1. **Audio Session Configuration**: The PTT framework controls the audio session. Our manual override might conflict.

2. **WebSocket Timing**: Audio chunks might arrive after the session is deactivated. The fix ensures the session stays active.

3. **App State**: The code skips native playback when app is in foreground (to avoid double playback with Flutter).

### Talk Button Implementation

To implement a proper talk button from lock screen, you need to choose one of these approaches:

#### Approach 1: System PTT UI (Best for iOS 16+)
```swift
// Request to begin transmitting using system PTT UI
channelManager.requestBeginTransmitting(channelUUID: channelUUID)
```

This will show the system PTT button in lock screen and Control Center.

#### Approach 2: Local Notification with Action
Show a local notification with a "Reply" action button that opens the app to record.

#### Approach 3: Custom Lock Screen UI
Use Live Activities (iOS 16.1+) to show a custom UI on the lock screen with a talk button.

## Summary of Changes

### File Modified
`ios/Runner/AppDelegate.swift`

### Changes Made
1. ✅ Set active remote participant when PTT push arrives
2. ✅ Clear remote participant after audio finishes
3. ✅ Added debug logging for queue processing
4. ✅ Added logging for audio player state transitions

### Impact
- 🔧 Fixes immediate session deactivation
- 🔧 Allows audio chunks to play in background
- 🔧 Keeps PTT session alive during transmission
- 📊 Better debugging with detailed logs

## Next Steps

1. **Test the audio playback fix** (most critical)
2. **Decide on talk button approach** (system PTT UI vs custom)
3. **Implement chosen talk button solution**

For now, the audio playback should work correctly. The talk button requires additional implementation based on your UX requirements.
