# 🔔 "App Woke Up (Token Only)" Notification - Explained & Fixed

## What You're Seeing

**Notification appears on iPhone when locked**:
```
Title: "App Woke Up (Token Only)"
Body: "Received PushToTalk token update in background. Audio blocked."
```

---

## What This Notification Means

This is a **DEBUG notification** that I added to help us debug VoIP push behavior. It appears when:

1. **iOS refreshes the VoIP token** (happens periodically, especially after app updates or device restarts)
2. The app wakes up in background
3. But there's NO actual PTT audio to play (just a token refresh)

### It's NOT An Error! ✅

**This notification appears**:
- ✅ When iOS updates your VoIP token (normal system behavior)
- ✅ When the app first installs
- ✅ After iOS updates
- ✅ After app updates

**This notification does NOT appear**:
- When actual PTT messages arrive (those play audio immediately)

---

## The Real Issue: Audio Not Playing When Locked

**If you're experiencing**:
> "why i get the notification of the app wake up (token only) received the pushtotalk token update in background audio blocked when iphone is locked"

This suggests **two separate issues**:

### Issue 1: Debug Notification (Harmless)
The "App Woke Up" notification is just debug info - doesn't affect PTT functionality.

### Issue 2: Audio Actually Blocked When Locked (REAL PROBLEM)
If actual PTT audio is blocked when iPhone is locked, this is a **serious issue** that needs fixing.

---

## Fix 1: Remove Debug Notification (Clean Up)

**Location**: `ios/Runner/AppDelegate.swift` Line ~999-1004

**Current Code** (with debug notification):
```swift
func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
    let token = pushToken.map { String(format: "%02x", $0) }.joined()
    print("📲 PTT Framework VoIP Token: \(token)")
    UserDefaults.standard.set(token, forKey: "voip_token")
    sendVoIPTokenToFlutter(token)
    
    // 🚨 DEBUG: Show a local notification
    let content = UNMutableNotificationContent()
    content.title = "App Woke Up (Token Only)"
    content.body = "Received PushToTalk token update in background. Audio blocked."
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
}
```

**Fixed Code** (debug notification removed):
```swift
func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
    let token = pushToken.map { String(format: "%02x", $0) }.joined()
    print("📲 PTT Framework VoIP Token: \(token)")
    UserDefaults.standard.set(token, forKey: "voip_token")
    sendVoIPTokenToFlutter(token)
    
    // ✅ Token refresh is normal - no notification needed
    print("✅ VoIP token refreshed and stored")
}
```

---

## Fix 2: Ensure Audio Plays When Locked (Critical)

If PTT audio is actually blocked when the iPhone is locked, we need to check the audio session activation.

### Check 1: Audio Session Configuration

**Location**: `ios/Runner/AppDelegate.swift` Line ~820-840 (NativePTTPlayer audio session)

Ensure the audio session is configured correctly:
```swift
private func activateAudioSessionForPTT() {
    do {
        let session = AVAudioSession.sharedInstance()
        
        // ✅ CRITICAL: Use .playback mode for background audio playback
        try session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .duckOthers, .allowBluetooth]
        )
        
        // ✅ CRITICAL: Activate the session
        try session.setActive(true)
        
        print("✅ AVAudioSession activated for PTT - background playback enabled")
    } catch {
        print("⚠️ Failed to activate audio session for PTT: \(error)")
    }
}
```

### Check 2: Background Audio Capability

**Location**: Xcode → Runner target → Signing & Capabilities

**Ensure these are enabled**:
- ✅ **Background Modes**:
  - Audio, AirPlay, and Picture in Picture ← CRITICAL!
  - Voice over IP
  - Background fetch
  - Remote notifications

**Location**: `ios/Runner/Info.plist`

**Ensure this exists**:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>        ← CRITICAL FOR LOCKED PLAYBACK!
    <string>voip</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

---

## Testing: Confirm Audio Works When Locked

### Test 1: Actual PTT Message When Locked
```
1. iPhone: Lock the screen
2. Android: Send PTT message
3. iPhone: Should hear audio immediately (screen stays locked)
4. ✅ CHECK: Did you hear the audio?
```

**Expected**: Audio plays through speaker (or earbuds if connected) ✅

**If broken**: No audio, or notification appears instead ❌

### Test 2: Differentiate Token Refresh vs PTT
```
Scenario A: Token Refresh (Harmless)
- iPhone shows "App Woke Up (Token Only)" notification
- No actual PTT message sent
- This is just iOS updating the VoIP token

Scenario B: Real PTT (Should Play Audio)
- Android sends PTT message
- iPhone should play audio immediately
- NO notification should appear
```

---

## Quick Fix Commands

### Step 1: Remove Debug Notification
```swift
// In ios/Runner/AppDelegate.swift Line ~999-1004
// DELETE these lines:
let content = UNMutableNotificationContent()
content.title = "App Woke Up (Token Only)"
content.body = "Received PushToTalk token update in background. Audio blocked."
let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
UNUserNotificationCenter.current().add(request)

// REPLACE with:
print("✅ VoIP token refreshed and stored")
```

### Step 2: Verify Background Audio Mode
```bash
# Check Info.plist has audio background mode:
cat ios/Runner/Info.plist | grep -A 5 UIBackgroundModes
```

**Should see**:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
    ...
</array>
```

### Step 3: Rebuild & Test
```bash
flutter clean
flutter build ios --release
# Then archive and upload to TestFlight
```

---

## Expected Behavior After Fix

### Before Fix:
```
iPhone locked → PTT arrives → Notification shows "App Woke Up" → No audio ❌
iPhone locked → Token refresh → Notification shows "App Woke Up" → Confusing
```

### After Fix:
```
iPhone locked → PTT arrives → Audio plays immediately → No notification ✅
iPhone locked → Token refresh → Silent (just a console log) → Clean ✅
```

---

## Root Cause Summary

### The Debug Notification
- **Purpose**: Debugging tool to see when app wakes up
- **Trigger**: VoIP token refresh (not actual PTT messages)
- **Problem**: Confusing, makes users think PTT is broken
- **Solution**: Remove it (we don't need it anymore)

### The Real Audio Issue (If Present)
- **Symptom**: No audio when iPhone is locked
- **Cause**: Audio session not properly activated for background playback
- **Solution**: Ensure `.audio` background mode is enabled + session activated correctly

---

## Files to Modify

### 1. `ios/Runner/AppDelegate.swift` (Line ~999-1004)
**Remove debug notification** from `receivedEphemeralPushToken` function

### 2. `ios/Runner/Info.plist`
**Verify** `UIBackgroundModes` includes `<string>audio</string>`

---

## Deployment

### Build & Upload:
```bash
cd /Users/pc/Downloads/agora_ptt
flutter clean
flutter pub get
flutter build ios --release
open ios/Runner.xcworkspace
```

Then in Xcode:
1. Archive
2. Upload to TestFlight
3. Test with locked iPhone

---

## Success Criteria

### ✅ After Fix:
1. No more "App Woke Up" notifications
2. PTT audio plays when iPhone is locked
3. Audio plays when iPhone is unlocked
4. Token refreshes happen silently (just console logs)

### ❌ Still Broken:
1. If audio still doesn't play when locked → Check `Info.plist` for audio background mode
2. If notifications still appear → Debug notification not removed

---

## Quick Test Checklist

```
☐ Remove debug notification from AppDelegate.swift
☐ Verify audio background mode in Info.plist
☐ Rebuild app with flutter clean
☐ Upload to TestFlight
☐ Lock iPhone
☐ Send PTT from Android
☐ Confirm audio plays on locked iPhone
☐ Confirm no debug notification appears
```

---

## Summary

**The notification you're seeing** = Debug notification for token refresh (harmless, but annoying)

**The real issue** = If PTT audio doesn't play when locked, ensure:
1. ✅ Audio background mode enabled in Info.plist
2. ✅ Audio session properly activated in NativePTTPlayer
3. ✅ Debug notification removed (clean up)

**Fix priority**:
1. Remove debug notification ← Easy, do now
2. Test if audio actually plays when locked
3. If audio doesn't play, check background mode settings

**Expected result**: PTT audio plays perfectly when iPhone is locked, no confusing notifications ✅
