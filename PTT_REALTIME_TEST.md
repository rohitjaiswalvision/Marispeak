# PTT Real-Time Streaming Test

## Expected Behavior (Walkie-Talkie)

### Scenario: User A sends 4.5-second message to User B

**Timeline**:
```
0.0s: User A presses PTT button
      → Recording starts
      → Timer starts

1.5s: First chunk recorded and sent
      → User B should START hearing audio now

3.0s: Second chunk recorded and sent  
      → User B continues hearing audio

4.5s: User A releases button
      → Third (final) chunk sent
      → User B finishes hearing complete message

Total: User B hears audio for ~4.5 seconds
Latency: ~0.5-1.0 seconds (acceptable for walkie-talkie)
```

## What You're Seeing (Problem)

**Current Timeline**:
```
0.0s: User A presses PTT button
      → Recording starts

1.5s: First chunk sent (silent on User B)
3.0s: Second chunk sent (silent on User B)

4.5s: User A RELEASES button
      → NOW User B suddenly hears all chunks at once

Problem: User B only hears audio AFTER button is released
```

## Root Cause

Looking at your logs:
```
flutter: 📦 Flutter received 5461 bytes of audio
🔊 Speaker output overridden
flutter: 🔊 Flutter playing audio chunk: .../rx_xxx.m4a (5461 bytes)
flutter: ✅ Flutter finished playing audio chunk
```

The audio IS being received and played. But you're saying it's not heard until button release.

**This suggests**:
1. ✅ Chunks are being sent in real-time (every 1.5s)
2. ✅ Chunks are being received immediately  
3. ❌ Something is BLOCKING playback until button is released

## Hypothesis

The issue might be:

### Option 1: Audio Session Not Active When First Chunk Arrives
The audio session is only activated when playback starts, but if there's a delay, the first chunk might be dropped.

### Option 2: FCM Notification Delays WebSocket Reconnection
When you send a message, an FCM notification is sent. This might be waking the receiver's app but NOT connecting the WebSocket until the notification is dismissed.

### Option 3: The 50ms Delay Is Too Long
The 50ms delay we added for file verification is causing chunks to queue up instead of playing immediately.

## Debug Test

### Test 1: Check Sender Logs

When you **press and hold** the PTT button for 4 seconds, you should see:

```
flutter: Button press allowed, starting timer and session
flutter: Timer Started, Instance of '_Timer'

// After 1.5 seconds:
flutter: 📤 Sending audio with channelUUID: xxx
flutter: sendMessage() -> success  (Firebase message)

// After 3.0 seconds:
flutter: 📤 Sending audio with channelUUID: xxx

// After 4.0 seconds (you release):
flutter: 📤 Sending audio with channelUUID: xxx
flutter: Timer Stopped
```

**Do you see these logs while HOLDING the button?**

### Test 2: Check Receiver Logs

When the other device receives your PTT, they should see:

```
// Immediately when first chunk arrives:
flutter: 📦 Flutter received 5461 bytes of audio
🔊 Speaker output overridden
flutter: 🔊 Flutter playing audio chunk: .../rx_xxx.m4a (5461 bytes)
flutter: ✅ Flutter finished playing audio chunk

// 1.5 seconds later (while you're still talking):
flutter: 📦 Flutter received 19598 bytes of audio
🔊 Speaker output overridden
flutter: 🔊 Flutter playing audio chunk: .../rx_yyy.m4a (19598 bytes)
flutter: ✅ Flutter finished playing audio chunk
```

**When do you see these logs? While sender is holding button, or only after release?**

## The Fix

Based on your description, I believe the issue is the **50ms delay**. Let me remove it and use instant playback with better error handling.

The file verification should happen in the `_processPlayQueue` function, not before queueing. This way, chunks start playing IMMEDIATELY without delay.

