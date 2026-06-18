# PTT Flow Diagram

## Before Fix ❌

```
┌─────────────────────────────────────────────────────────┐
│ 1. PTT Push Arrives on Lock Screen                     │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 2. incomingPushResult() called                          │
│    - groupId NOT stored ❌                              │
│    - Returns participant                                 │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 3. PTT Framework Actions                                │
│    - didActivate: Audio session starts ✅               │
│    - NO active participant set ❌                       │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 4. PTT Framework Thinks Session is Over ❌              │
│    - didDeactivate: Audio session ends immediately      │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 5. NativePTTPlayer.disconnect() ❌                      │
│    - isAudioSessionActive = false                        │
│    - processQueue() cannot run                           │
│    - Audio chunks never play 🔇                         │
└─────────────────────────────────────────────────────────┘
```

## After Fix ✅

```
┌─────────────────────────────────────────────────────────┐
│ 1. PTT Push Arrives on Lock Screen                     │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 2. incomingPushResult() called                          │
│    - groupId stored ✅                                  │
│    - NativePTTPlayer.currentGroupId = groupId           │
│    - Returns .activeRemoteParticipant(participant) ✅   │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 3. PTT Framework Actions                                │
│    - Sees active remote participant ✅                  │
│    - didActivate: Audio session starts ✅               │
│    - Shows system PTT UI 🎛️                            │
│    - Session stays alive ⏱️                             │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 4. NativePTTPlayer Receives Audio                       │
│    - WebSocket connected ✅                             │
│    - sessionDidActivate() → isAudioSessionActive = true │
│    - Audio chunks arrive → added to queue               │
│    - processQueue() runs ✅                             │
│    - Audio plays at full volume 🔊                      │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 5. User Can Reply                                       │
│    - Talk button available in system UI 🎙️             │
│    - User presses button → didBeginTransmittingFrom     │
│    - groupId available ✅                               │
│    - startTransmitting(groupId) ✅                      │
│    - Voice recorded and sent 📤                         │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ 6. Clean Session End                                    │
│    - Audio finishes → wait 3.5s                         │
│    - No more chunks → post PTTAudioFinished             │
│    - Clear remote participant → session ends gracefully │
│    - didDeactivate: Audio session stops ✅              │
└─────────────────────────────────────────────────────────┘
```

## Talk Button Flow

```
┌─────────────────────────────────────────────────────────┐
│ User Sees PTT UI on Lock Screen                         │
│                                                          │
│  ┌────────────────────────────────────────┐            │
│  │  🎛️ Walkie-Talkie                     │            │
│  │  🔊 User is speaking...                │            │
│  │                                        │            │
│  │  [ Press to Talk ] 🎙️                 │            │
│  └────────────────────────────────────────┘            │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ User presses and holds button
                  ▼
┌─────────────────────────────────────────────────────────┐
│ didBeginTransmittingFrom() called                       │
│                                                          │
│  1. Check currentGroupId ✅                             │
│  2. If nil, check UserDefaults fallback ✅              │
│  3. Call startTransmitting(groupId) ✅                  │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ NativePTTPlayer.startTransmitting()                     │
│                                                          │
│  1. Connect WebSocket if not connected                  │
│  2. Register and switch to groupId                      │
│  3. Start recording 1.5s chunks                         │
│  4. Send chunks via WebSocket                           │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ User releases button
                  ▼
┌─────────────────────────────────────────────────────────┐
│ didEndTransmittingFrom() called                         │
│                                                          │
│  1. Stop recording                                      │
│  2. Send final chunk                                    │
│  3. Clean up                                            │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ Other User Receives Message ✅                          │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### PTT Framework (iOS 16+)
```
┌──────────────────────────────┐
│   PTChannelManager           │
│                              │
│  • Manages PTT sessions      │
│  • Shows system UI           │
│  • Calls delegates           │
│  • Wakes app from killed     │
└──────────────────────────────┘
```

### NativePTTPlayer (Your Code)
```
┌──────────────────────────────┐
│   NativePTTPlayer            │
│                              │
│  • WebSocket connection      │
│  • Audio playback queue      │
│  • Audio recording           │
│  • Chunk transmission        │
└──────────────────────────────┘
```

### AppDelegate (Glue Code)
```
┌──────────────────────────────┐
│   AppDelegate                │
│                              │
│  • PTT Framework delegates   │
│  • Coordinate components     │
│  • Store groupId             │
│  • Manage session lifecycle  │
└──────────────────────────────┘
```

## Data Flow

### Receiving Audio
```
VoIP Push
    ↓
incomingPushResult()
    ↓
Store groupId + Return participant
    ↓
PTT Framework keeps session alive
    ↓
didActivate()
    ↓
NativePTTPlayer.sessionDidActivate()
    ↓
WebSocket connects
    ↓
Audio chunks arrive
    ↓
Add to queue
    ↓
processQueue()
    ↓
playAudio()
    ↓
🔊 Sound plays on speaker
```

### Sending Audio
```
User presses talk button
    ↓
didBeginTransmittingFrom()
    ↓
Get groupId from currentGroupId
    ↓
NativePTTPlayer.startTransmitting(groupId)
    ↓
WebSocket connects (if needed)
    ↓
Start recording
    ↓
Every 1.5s: sendAudioChunk()
    ↓
Base64 encode + WebSocket.send()
    ↓
Server receives
    ↓
Server forwards to other users
    ↓
User releases button
    ↓
didEndTransmittingFrom()
    ↓
Stop recording + send final chunk
    ↓
✅ Transmission complete
```

## Critical Success Factors

### ✅ Must Have
1. **Return `.activeRemoteParticipant`** - Keeps session alive
2. **Store `currentGroupId`** - Enables reply functionality
3. **Call `sessionDidActivate()`** - Enables audio playback
4. **Wait 3.5s before ending** - Don't cut off multi-chunk audio

### ❌ Must Avoid
1. **Don't call `disconnect()` too early** - Kills audio playback
2. **Don't forget to store groupId** - Breaks reply functionality
3. **Don't start playback before session is active** - Audio won't play
4. **Don't return wrong PTPushResult** - Session ends immediately

## Comparison Table

| Aspect | Before Fix | After Fix |
|--------|-----------|-----------|
| Session Duration | 0.1s (immediate end) | Until audio finishes + 3.5s |
| Audio Playback | ❌ Never plays | ✅ Plays at full volume |
| Talk Button | ❌ No UI shown | ✅ System UI available |
| Reply Capability | ❌ No groupId | ✅ groupId stored |
| Lock Screen Support | ❌ Broken | ✅ Fully working |
| Killed App Support | ❌ App wakes but no audio | ✅ Wakes and plays audio |

---

This diagram shows the complete flow from receiving a PTT message on lock screen to being able to reply using the talk button. The key insight is that returning `.activeRemoteParticipant` tells the PTT framework to treat this as an active conversation, which keeps the session alive long enough for audio to play and for the user to respond.
