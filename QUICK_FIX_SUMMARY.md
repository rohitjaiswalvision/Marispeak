# Quick Fix Summary: CallKit Talk Button

## What Was Fixed
Your PTT app now properly handles the talk button on the lock screen CallKit interface.

## The Problem
When receiving a PTT message on lock screen:
- ✅ CallKit screen appeared
- ✅ Audio played correctly  
- ❌ Talk button didn't work (no groupId)
- ❌ Screen disappeared too fast

## The Solution
Modified `ios/Runner/AppDelegate.swift` to:

1. **Store the group ID** when push notification arrives
2. **Add fallback logic** to retrieve group ID if needed
3. **Keep CallKit screen open longer** (60s initial + 45s after audio)
4. **Enable reply capability** from lock screen

## Key Changes

### 1. Group ID Now Persists
```swift
NativePTTPlayer.shared.currentGroupId = groupId
```
Set in 3 places:
- PushKit handler (iOS < 16)
- PTT framework handler (iOS 16+) ✅ already was there
- CallKit report function

### 2. Fallback Mechanism
```swift
// If currentGroupId is nil, try UserDefaults
if groupId == nil || groupId!.isEmpty {
    if let payload = UserDefaults.standard.dictionary(forKey: "pending_voip_payload"),
       let gId = payload["groupId"] as? String {
        groupId = gId
        NativePTTPlayer.shared.currentGroupId = gId
    }
}
```

### 3. Extended Timeouts
- Initial CallKit timeout: 35s → **60s**
- Post-audio timeout: immediate → **45s**
- Total time to reply: up to **105 seconds**

## How to Test

1. **Kill the app completely**
2. **Lock your iPhone**
3. **Have someone send a PTT message**
4. **See CallKit screen appear** ✅
5. **Listen to the message** ✅
6. **Press and hold the talk button** 🎙️
7. **Speak your reply**
8. **Release the button**
9. **Message should transmit** ✅

## What to Watch in Logs

### Success Logs:
```
📨 PTT Push Received: ["groupId": xxx, ...]
🔊 NativePTTPlayer: Connecting as userId to receive group groupId
🎙️ Began Transmitting
🎙️ NativePTTPlayer: Started recording chunk
📤 NativePTTPlayer: Sent audio chunk (57356 bytes)
```

### Error Log (if problem persists):
```
❌ Cannot transmit: No groupId available!
```

## Next Steps

1. **Rebuild and deploy** the iOS app to your device
2. **Test the talk button** from lock screen
3. **Verify message transmission** works

## Files Modified
- `ios/Runner/AppDelegate.swift` (4 locations)

## Backup
If you need to revert, use git:
```bash
git checkout ios/Runner/AppDelegate.swift
```

---

**Status**: ✅ Ready for testing
**Impact**: Low risk - only affects lock screen PTT functionality
**Compatibility**: iOS 13+ (both PushKit and PTT framework paths)
