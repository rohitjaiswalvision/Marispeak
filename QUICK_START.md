# 🚀 Quick Start: Testing PTT Without Affecting Production

## ⚡ 3-Step Setup (5 minutes)

### Step 1: Switch to Development Environment

Open: `lib/config/environment.dart`

Find line 25:
```dart
static Environment current = development; // <-- Change this
```

**✅ For Testing:** Keep it as `development`  
**❌ For Production:** Change to `production`

---

### Step 2: Start Your Development Server

```bash
cd railway_server
npm install
npm start
```

Server will run on `ws://localhost:3000`

---

### Step 3: Run Your App

```bash
flutter run
```

Check console for:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Environment: Development
  PTT Server: ws://localhost:3000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **You're now testing safely without affecting production!**

---

## 🎯 Quick Reference

### Where to Change Environment

**File:** `lib/config/environment.dart`  
**Line:** ~25

```dart
// Testing locally
static Environment current = development;

// Testing on staging server
static Environment current = staging;

// Production (REAL USERS)
static Environment current = production;
```

---

### Environment URLs

| Environment | PTT Server | Purpose |
|-------------|------------|---------|
| development | `ws://localhost:3000` | Local testing |
| staging | `wss://ptt-staging.visionvivante.in` | Pre-production |
| production | `wss://ptt.visionvivante.in` | Live users |

---

## ✅ Testing Checklist

**Before Testing:**
- [ ] Environment set to `development`
- [ ] Local server running (`npm start`)
- [ ] App shows "Development" in console

**Test PTT:**
- [ ] Open chat
- [ ] Press PTT button
- [ ] See "Connected as [userId]" in logs
- [ ] Send audio
- [ ] Hear audio playback

**Before Production Release:**
- [ ] Environment set to `production`
- [ ] Test on production server
- [ ] Build release: `flutter build ios --release`

---

## 🆘 Troubleshooting

### "Can't connect to server"

**Check:**
1. Is server running? `npm start` in `railway_server/`
2. Is environment correct? Check console logs
3. Port correct? Default is `3000`

### "Still connecting to production"

**Solution:**
1. Open `lib/config/environment.dart`
2. Change line 25 to: `static Environment current = development;`
3. Hot restart app (`R` in terminal)

### "How do I know which environment I'm in?"

**Check console at app startup:**
```
Environment: Development  <-- Your current environment
```

Or add visual indicator (optional):
```dart
// In your main screen
EnvironmentCornerBadge()
```

---

## 📱 Visual Environment Indicator (Optional)

Add to your main screen to see environment at all times:

```dart
import 'package:marispeaks/widgets/environment_banner.dart';

// In your Scaffold
Stack(
  children: [
    YourScreen(),
    EnvironmentCornerBadge(), // Shows "DEV" badge in corner
  ],
)
```

---

## 🔒 Pre-Release Checklist

Before submitting to App Store:

```dart
// 1. Open lib/config/environment.dart
static Environment current = production; // ✅

// 2. Build release
flutter build ios --release

// 3. Test release build
// 4. Submit
```

---

## 📚 Full Documentation

- **Complete Guide:** `ENVIRONMENT_SWITCHING_GUIDE.md`
- **PTT Health Check:** `PTT_HEALTH_CHECK_REPORT.md`
- **Environment Config:** `lib/config/environment.dart`

---

## 💡 Remember

- ✅ `development` = Safe testing (local server)
- ⚠️ `staging` = Pre-production testing
- 🚨 `production` = Real users (be careful!)

**Always test in development first!**
