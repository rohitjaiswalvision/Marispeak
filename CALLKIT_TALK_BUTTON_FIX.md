# CallKit Talk Button Fix

## Problem
When the app is in lock screen and a PTT push notification arrives:
1. CallKit screen appears ✅
2. Audio plays correctly ✅
3. User presses the talk button to reply ❌
4. Message doesn't send because `currentGroupId` is not set ❌
5. CallKit screen disappears too quickly, preventing user from replying ❌

## Root Causes
1. **Missing Group ID**: The `NativePTTPlayer.shared.currentGroupId` was not being set when VoIP push was received
2. **Early Dismissal**: CallKit screen was auto-ending too quickly (35s or immediately after audio finished)
3. **No Fallback**: The `didBeginTransmittingFrom` method had no fallback when `currentGroupId` was nil

## Changes Made

### 1. Set Group ID in PushKit Handler (iOS < 16)
**File**: `ios/Runner/AppDelegate.swift`
**Location**: `pushRegistry(_:didReceiveIncomingPushWith:)` method

```swift
// ✅ CRITICAL: Store the groupId so the talk button knows where to send replies
if !groupId.isEmpty {
    NativePTTPlayer.shared.currentGroupId = groupId
    NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
    ...
}
```

### 2. Set Group ID in CallKit Report Function
**File**: `ios/Runner/AppDelegate.swift`
**Location**: `reportPTTCallKitCall(senderName:groupId:)` method

```swift
// ✅ CRITICAL: Store the groupId so the talk button knows where to send replies
if !groupId.isEmpty {
    NativePTTPlayer.shared.currentGroupId = groupId
}
```

### 3. Add Fallback in Transmit Handler
**File**: `ios/Runner/AppDelegate.swift`
**Location**: `channelManager(_:channelUUID:didBeginTransmittingFrom:)` method

```swift
func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
    print("🎙️ Began Transmitting")
    
    // ✅ Get the groupId from either cached value or try to retrieve from pending push
    var groupId = NativePTTPlayer.shared.currentGroupId
    
    if groupId == nil || groupId!.isEmpty {
        // ⚠️ Fallback: Try to get groupId from the pending VoIP payload
        if let payload = UserDefaults.standard.dictionary(forKey: "pending_voip_payload"),
           let gId = payload["groupId"] as? String {
            groupId = gId
            NativePTTPlayer.shared.currentGroupId = gId
            print("🔄 Retrieved groupId from pending payload: \(gId)")
        }
    }
    
    if let groupId = groupId, !groupId.isEmpty {
        NativePTTPlayer.shared.startTransmitting(groupId: groupId)
    } else {
        print("❌ Cannot transmit: No groupId available!")
    }
}
```

### 4. Extended CallKit Screen Timeout
**File**: `ios/Runner/AppDelegate.swift`
**Location**: `reportPTTCallKitCall(senderName:groupId:)` method

Changed from 35s to 60s:
```swift
// ✅ Extend auto-end timeout to 60s to give user time to reply
DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) { [weak self] in
    guard let self = self, let uuid = self.activeCallUUID else { return }
    self.endPTTCallKitCall(uuid: uuid)
}
```

### 5. Delayed CallKit Dismissal After Audio Finishes
**File**: `ios/Runner/AppDelegate.swift`
**Location**: PTTAudioFinished notification handler

Changed to keep CallKit screen open for 45s after audio finishes:
```swift
// ✅ DON'T auto-end CallKit call — let user dismiss or use talk button to reply
// Only end it if no action is taken within 45 seconds
DispatchQueue.main.asyncAfter(deadline: .now() + 45.0) { [weak self] in
    guard let self = self, let uuid = self.activeCallUUID else { return }
    self.endPTTCallKitCall(uuid: uuid)
}
```

## Testing Instructions

1. **Force kill the app** (swipe up from app switcher)
2. **Send a PTT message** from another device
3. **Verify CallKit screen appears** on lock screen
4. **Wait for audio to play** (should play at full volume)
5. **Press the talk button** on CallKit screen
6. **Hold and speak** your reply message
7. **Release the talk button**
8. **Verify the message is sent** to the other device

## Expected Behavior After Fix

✅ CallKit screen appears when app is killed
✅ Audio plays at full volume
✅ CallKit screen stays visible for reply
✅ Talk button works correctly
✅ Message is transmitted to the group
✅ CallKit screen auto-dismisses after 45s of inactivity
✅ User can manually dismiss CallKit screen at any time

## Logs to Watch

When testing, you should see these logs in Xcode console:

```
📨 PTT Push Received: ["groupId": xxx, "senderName": User, "type": ptt]
🔊 NativePTTPlayer: Connecting as userId to receive group groupId
✅ NativePTTPlayer: WebSocket connected
🔊 NativePTTPlayer: Received XXXX bytes of audio
🎙️ PTT Audio Session Activated
✅ NativePTTPlayer: Audio chunk playing at full volume on speaker
🎙️ Began Transmitting
🎙️ NativePTTPlayer: Started recording chunk to tx_XXXX.m4a
🎙️ Ended Transmitting
📤 NativePTTPlayer: Sent audio chunk (XXXX bytes)
```

If you see `❌ Cannot transmit: No groupId available!`, the fix didn't work properly.

## Notes

- The `currentGroupId` is now persisted across the entire PTT session
- CallKit screen will stay open longer to allow for natural conversation flow
- The talk button now has a fallback mechanism to retrieve groupId from UserDefaults
- PTT framework (iOS 16+) already had the groupId caching, now PushKit path (iOS < 16) also has it
