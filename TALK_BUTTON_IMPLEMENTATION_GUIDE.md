# Talk Button Implementation Guide

## Current Situation

Your app uses the PTT Framework (iOS 16+) which:
- ✅ Wakes app from killed state
- ✅ Plays audio in background
- ❌ Does NOT show a talk button UI automatically

## Why You Don't See a Talk Button

The PTT framework has two modes:

### 1. Silent Mode (Current)
- Audio plays in background
- No UI shown
- No talk button available
- User cannot reply from lock screen

### 2. Interactive Mode (What You Want)
- Audio plays in background
- System PTT UI shown (like FaceTime audio controls)
- Talk button available in lock screen
- User can press and hold to reply

## How to Enable Talk Button

You need to make the PTT channel **interactive** by requesting user attention.

### Option 1: Show System PTT UI (Recommended)

Add this to your `incomingPushResult` method:

```swift
func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult {
    print("📨 PTT Push Received: \(pushPayload)")

    let groupId = pushPayload["groupId"] as? String ?? ""
    let senderName = pushPayload["senderName"] as? String ?? "Walkie-Talkie"
    NativePTTPlayer.shared.currentGroupId = groupId

    // ✅ Set active remote participant
    let participant = PTParticipant(name: senderName, image: nil)
    channelManager.setActiveRemoteParticipant(participant, channelUUID: channelUUID) { error in
        if let error = error {
            print("❌ Failed to set active participant: \(error)")
        } else {
            print("✅ Set active remote participant: \(senderName)")
        }
    }

    // ✅ Start background audio
    DispatchQueue.main.async {
        if UIApplication.shared.applicationState != .active {
            if !groupId.isEmpty {
                NativePTTPlayer.shared.startBackgroundReceive(groupId: groupId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NativePTTPlayer.shared.sessionDidActivate()
                }
            }
        }
    }

    // ✅ Return .leaveChannelAndPostpone to show system UI
    // This tells iOS: "Show the PTT UI with talk button"
    return .leaveChannelAndPostpone
}
```

**Key Change**: Return `.leaveChannelAndPostpone` instead of ignoring the return value.

### What This Does

When you return `.leaveChannelAndPostpone`:
1. iOS shows a system notification/UI
2. User sees who is talking
3. A talk button appears
4. User can press and hold to reply
5. Your `didBeginTransmittingFrom` gets called

### Option 2: Use Local Notification with Actions

If the system PTT UI doesn't work as expected, use a local notification:

```swift
func incomingPushResult(...) -> PTPushResult {
    // ... existing code ...
    
    // Show local notification with reply action
    let content = UNMutableNotificationContent()
    content.title = senderName
    content.body = "Press to reply"
    content.sound = nil // Audio already playing
    content.categoryIdentifier = "PTT_REPLY"
    
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )
    
    UNUserNotificationCenter.current().add(request)
    
    return .leaveChannelAndPostpone
}

// In application(_:didFinishLaunchingWithOptions:)
func setupNotificationActions() {
    let replyAction = UNNotificationAction(
        identifier: "REPLY_ACTION",
        title: "Reply",
        options: [.authenticationRequired]
    )
    
    let category = UNNotificationCategory(
        identifier: "PTT_REPLY",
        actions: [replyAction],
        intentIdentifiers: [],
        options: [.customDismissAction]
    )
    
    UNUserNotificationCenter.current().setNotificationCategories([category])
}
```

### Option 3: Use CallKit with Custom UI

Show a full-screen CallKit call with a custom UI:

```swift
func incomingPushResult(...) -> PTPushResult {
    // ... existing code ...
    
    // If app was killed, show CallKit UI
    if !hasBeenInForeground {
        reportPTTCallKitCall(senderName: senderName, groupId: groupId)
    }
    
    return .leaveChannelAndPostpone
}
```

This shows a full incoming call screen where the user can:
- Answer to open the app
- Decline to dismiss
- Use talk button if implemented in your app UI

## Recommended Approach

**For Lock Screen Talk Button**: Use Option 1 (System PTT UI)
- Native iOS experience
- Minimal code changes
- Automatic UI handling
- Built-in talk button

**For Full Control**: Use Option 2 (Local Notification) or Option 3 (CallKit)
- More control over UX
- Can customize appearance
- Requires more implementation

## Testing After Implementation

1. **Kill the app**
2. **Lock the iPhone**
3. **Have someone send PTT message**
4. **Observe**:
   - Screen wakes up
   - PTT notification/UI appears
   - You hear the audio
   - You see a talk button or reply option
5. **Press and hold talk button**
6. **Speak your reply**
7. **Release**
8. **Verify message sends**

## Important Notes

### PTT Framework Limitations

The PTT framework is designed for **walkie-talkie style** apps where:
- Users are in an always-active channel
- Push notifications are supplementary
- Main interaction happens in-app

For **messenger-style** PTT (like WhatsApp voice messages):
- Consider using CallKit + custom UI
- Or use local notifications with actions
- System PTT UI might feel out of place

### Current Architecture Issue

Your app tries to play audio **natively in background** but also **in Flutter when active**. This dual approach causes complexity.

**Consider**:
- Always use native playback (even when app active)
- Or always use Flutter (wake app for playback)
- Mixed mode is hard to maintain

## Quick Fix to Test

To quickly test if the talk button can work, add this single line:

**File**: `ios/Runner/AppDelegate.swift`
**Location**: End of `incomingPushResult` method

```swift
func incomingPushResult(...) -> PTPushResult {
    // ... all existing code ...
    
    return .leaveChannelAndPostpone  // ✅ Add this line
}
```

Rebuild, kill app, lock phone, have someone send message. You should see a system UI appear.

## Current Code Status

With the previous fix:
- ✅ Audio session stays alive
- ✅ Audio chunks can play
- ✅ Remote participant is set
- ❌ No talk button UI yet (requires implementation choice above)

Choose your preferred approach and let me know which one to implement!
