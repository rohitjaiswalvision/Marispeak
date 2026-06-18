# ✅ PTT Testing Setup Complete!

Your PTT app now has a complete development/production environment system. You can safely test without affecting production users.

---

## 🎯 What I've Set Up For You

### 1. **Environment Configuration System** ✅
- **File:** `lib/config/environment.dart`
- **Purpose:** Switch between development, staging, and production
- **How:** Change one line to switch environments

### 2. **Updated PTT Controller** ✅
- **File:** `lib/screens/ptt/websocket_ptt_controller.dart`
- **Change:** Now uses environment-based server URLs
- **Benefit:** Automatically connects to the right server

### 3. **Updated Main App** ✅
- **File:** `lib/main.dart`
- **Change:** Shows environment info at startup
- **Benefit:** Always know which environment you're in

### 4. **Debug Widgets** ✅
- **File:** `lib/debug_ptt_status.dart`
- **Purpose:** Check PTT connection status in real-time
- **Benefit:** Quickly verify PTT is working

### 5. **Visual Indicators** ✅
- **File:** `lib/widgets/environment_banner.dart`
- **Purpose:** Show environment on screen
- **Benefit:** Prevent accidental production testing

### 6. **Documentation** ✅
- `QUICK_START.md` - Fast 3-step guide
- `ENVIRONMENT_SWITCHING_GUIDE.md` - Complete instructions
- `PTT_HEALTH_CHECK_REPORT.md` - Detailed analysis
- `TESTING_SETUP_COMPLETE.md` - This file

### 7. **Helper Scripts** ✅
- `start_dev_environment.sh` - Auto-start dev server
- `test_ptt_connection.sh` - Test server connectivity

---

## 🚀 How to Start Testing RIGHT NOW

### Option 1: Quick Test (3 steps, 2 minutes)

**Step 1:** Open `lib/config/environment.dart`, line 25:
```dart
static Environment current = development; // ✅ Already set!
```

**Step 2:** Start your local PTT server:
```bash
cd railway_server
npm install  # Only first time
npm start
```

**Step 3:** Run your app in a new terminal:
```bash
flutter run
```

✅ **Done!** You're now testing on a local server, production is safe.

---

### Option 2: Use Staging Server (If you have one)

**Step 1:** Update staging URL in `lib/config/environment.dart`:
```dart
static const Environment staging = Environment(
  pttServerUrl: 'wss://your-staging-server.com', // Your staging URL
  // ...
);
```

**Step 2:** Switch to staging:
```dart
static Environment current = staging; // Line 25
```

**Step 3:** Run your app:
```bash
flutter run
```

---

### Option 3: Test on Production (With test accounts)

⚠️ **Only if you must!**

**Step 1:** Keep production environment:
```dart
static Environment current = production;
```

**Step 2:** Create test accounts:
- `test1@marispeak.com`
- `test2@marispeak.com`

**Step 3:** Test only between test accounts

---

## 📋 Files You Need to Know

### Main Configuration File (Most Important!)
```
lib/config/environment.dart  <-- Change line 25 to switch environments
```

### Files That Were Updated
```
lib/screens/ptt/websocket_ptt_controller.dart  <-- Now uses Environment.current.pttServerUrl
lib/main.dart                                    <-- Shows environment at startup
```

### New Files You Can Use
```
lib/debug_ptt_status.dart              <-- PTT status dialog
lib/widgets/environment_banner.dart    <-- Visual environment indicator
```

### Documentation
```
QUICK_START.md                         <-- Read this first!
ENVIRONMENT_SWITCHING_GUIDE.md         <-- Complete guide
PTT_HEALTH_CHECK_REPORT.md             <-- PTT analysis
```

### Helper Scripts
```
start_dev_environment.sh               <-- Auto-start dev server
test_ptt_connection.sh                 <-- Test server connection
```

---

## 🔍 How to Verify Your Setup

### Check #1: Environment Configuration

**Look at:** `lib/config/environment.dart`, line 25

**Should see:**
```dart
static Environment current = development; // For testing
```

**Or:**
```dart
static Environment current = production; // For production
```

### Check #2: Run Your App

**Command:**
```bash
flutter run
```

**Look for in console:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Environment: Development
  PTT Server: ws://localhost:3000
  Logging: Enabled
  Debug: Enabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ Running in DEVELOPMENT mode
```

✅ If you see this, you're set up correctly!

### Check #3: PTT Connection

**In app logs, look for:**
```
🔌 Connecting to PTT server: ws://localhost:3000
✅ Connected as [your_user_id]
```

✅ If you see this, PTT is working!

---

## 🎨 Optional: Add Visual Environment Indicator

### Show environment badge in app (recommended during testing)

**Add to your main screen:**

```dart
// Import the widget
import 'package:marispeaks/widgets/environment_banner.dart';

// In your build method, wrap your screen:
EnvironmentBanner(
  child: YourScreen(),
)

// Or add a floating badge:
Stack(
  children: [
    YourScreen(),
    EnvironmentCornerBadge(), // Shows "DEV" badge
  ],
)
```

**Result:** You'll see an orange "DEVELOPMENT MODE" banner or badge.

**Benefit:** Always know which environment you're in!

---

## 🧪 Testing Your PTT

### Full Test (2 devices needed)

**Device 1:**
1. Run app
2. Sign in with account A
3. Go to chat with account B
4. Press and hold PTT button
5. Speak for 3 seconds
6. Release button

**Device 2:**
1. Run app
2. Sign in with account B
3. Go to chat with account A
4. Listen for audio from device 1

✅ **Success:** Audio plays on device 2

### Solo Test (Check connection)

1. Run app
2. Sign in
3. Check logs for:
   ```
   ✅ Connected as [user_id]
   🎧 PTT Controller Ready
   ```

4. Press PTT button
5. Check logs for:
   ```
   👥 Joined group [group_id]
   Recording started
   ```

✅ **Success:** No errors, recording works

---

## 📱 Before App Store Release

### Pre-Release Checklist

**1. Switch to Production** ⚠️
```dart
// In lib/config/environment.dart, line 25:
static Environment current = production; // ✅
```

**2. Remove Debug Widgets** (if you added them)
```dart
// Remove:
EnvironmentBanner(...)
EnvironmentCornerBadge(...)
```

**3. Test Production Build**
```bash
flutter build ios --release
# Test the release build on device
```

**4. Verify in Logs**
```
Environment: Production
PTT Server: wss://ptt.visionvivante.in
```

**5. Submit to App Store**

✅ **Done!**

---

## 🆘 Common Issues & Solutions

### Issue: "Can't connect to PTT server"

**Solution:**

**If using development:**
```bash
# Start your local server
cd railway_server
npm start
```

**If using production:**
- Check production server status
- Verify internet connection
- Check firewall settings

### Issue: "Still connecting to production server"

**Solution:**
1. Open `lib/config/environment.dart`
2. Find line 25: `static Environment current = ...`
3. Change to: `static Environment current = development;`
4. Save file
5. Hot restart app (press `R` in terminal)

### Issue: "How do I know which environment I'm in?"

**Solution:**

**Check console output:**
```
Environment: Development  <-- Your environment
```

**Or use debug widget:**
```dart
import 'package:marispeaks/debug_ptt_status.dart';

// Show status dialog
PTTStatusDialog()
```

### Issue: "Server won't start"

**Solution:**
```bash
# Check if port 3000 is in use
lsof -i :3000

# If in use, kill the process
kill -9 [PID]

# Try starting server again
npm start
```

---

## 💡 Pro Tips

### Tip 1: Quick Environment Check
```dart
import 'package:marispeaks/config/environment.dart';

// Anywhere in your code:
print('Environment: ${Environment.current.name}');
print('Server: ${Environment.current.pttServerUrl}');
```

### Tip 2: Prevent Production Accidents
```dart
// Add this check in your code:
if (Environment.current.isProduction) {
  // Extra confirmation before critical actions
}
```

### Tip 3: Use Visual Indicators During Testing
```dart
// Add to your main screen while testing
if (!Environment.current.isProduction) {
  EnvironmentCornerBadge()
}
```

### Tip 4: Automated Server Start
```bash
# Make script executable (one time)
chmod +x start_dev_environment.sh

# Start everything with one command
./start_dev_environment.sh
```

---

## 📚 Next Steps

### 1. Read Quick Start
```bash
cat QUICK_START.md
```

### 2. Start Testing
```bash
# Terminal 1: Start server
cd railway_server && npm start

# Terminal 2: Run app
flutter run
```

### 3. Test PTT
- Open chat
- Press PTT button
- Check logs
- Send audio
- Verify playback

### 4. Before Production
- Switch to `production` in `environment.dart`
- Build release version
- Test thoroughly
- Submit to app store

---

## ✅ Summary

### You Now Have:
- ✅ Environment switching system
- ✅ Development/staging/production configurations
- ✅ Automatic server URL selection
- ✅ Debug tools and widgets
- ✅ Visual environment indicators
- ✅ Complete documentation
- ✅ Helper scripts

### Your Code is Safe:
- ✅ Testing won't affect production
- ✅ One line to switch environments
- ✅ Clear visual indicators
- ✅ Comprehensive logging

### You're Ready To:
- ✅ Test PTT locally
- ✅ Test on staging
- ✅ Deploy to production safely
- ✅ Debug issues easily

---

## 🎯 One-Line Summary

**Change line 25 in `lib/config/environment.dart` to switch between development and production. That's it!**

---

## 📞 Need Help?

**Check these files:**
1. `QUICK_START.md` - Fast setup guide
2. `ENVIRONMENT_SWITCHING_GUIDE.md` - Detailed instructions
3. `PTT_HEALTH_CHECK_REPORT.md` - PTT analysis

**Or check the code:**
- `lib/config/environment.dart` - Main configuration
- `lib/debug_ptt_status.dart` - Debug tools
- `lib/widgets/environment_banner.dart` - Visual indicators

---

## 🎉 You're All Set!

Your PTT testing environment is ready. Start testing safely without affecting production users!

**Quick start command:**
```bash
./start_dev_environment.sh  # Start dev server
# Then in new terminal:
flutter run                  # Run app
```

Happy testing! 🚀
