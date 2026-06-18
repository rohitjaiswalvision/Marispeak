# 🔄 Environment Switching Guide

This guide explains how to safely switch between development, staging, and production environments for testing your PTT feature.

---

## 🚀 Quick Start

### Step 1: Choose Your Environment

Open `lib/config/environment.dart` and find this line:

```dart
static Environment current = development; // <-- Change this line
```

**Change it to one of these:**

```dart
// For local testing (development server)
static Environment current = development;

// For staging/pre-production testing
static Environment current = staging;

// For production (live users)
static Environment current = production;
```

### Step 2: Run Your App

```bash
flutter run
```

When the app starts, you'll see the environment info in the console:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Environment: Development
  PTT Server: ws://localhost:3000
  API Server: https://dev-api.marispeak.com
  Logging: Enabled
  Debug: Enabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ Running in DEVELOPMENT mode - Do not release to production!
```

---

## 🔧 Environment Configurations

### 1. 🛠️ Development Environment

**When to use:**
- Testing on your local machine
- Debugging PTT features
- Developing new features

**Configuration:**
```dart
static Environment current = development;
```

**Server URLs:**
- PTT Server: `ws://localhost:3000`
- API Server: `https://dev-api.marispeak.com`

**Features:**
- ✅ All logging enabled
- ✅ Debug features enabled
- ✅ Connects to local development server

**Setup Required:**
1. Run your local PTT server on port 3000
2. Or change the URL in `environment.dart` to your dev server

---

### 2. 🧪 Staging Environment

**When to use:**
- Testing before production release
- QA testing with staging data
- Integration testing

**Configuration:**
```dart
static Environment current = staging;
```

**Server URLs:**
- PTT Server: `wss://ptt-staging.visionvivante.in`
- API Server: `https://staging-api.marispeak.com`

**Features:**
- ✅ Logging enabled
- ✅ Debug features enabled
- ✅ Connects to staging server (separate from production)

**Setup Required:**
1. Ensure you have a staging server running
2. Update the URL in `environment.dart` if different

---

### 3. 🚀 Production Environment

**When to use:**
- Building release versions
- Submitting to App Store/Play Store
- Live users

**Configuration:**
```dart
static Environment current = production;
```

**Server URLs:**
- PTT Server: `wss://ptt.visionvivante.in`
- API Server: `https://api.marispeak.com`

**Features:**
- ❌ Minimal logging
- ❌ Debug features disabled
- ✅ Connects to production server

**⚠️ IMPORTANT:**
Always set to production before releasing to app stores!

---

## 📝 How to Test Without Affecting Production

### Option 1: Use Development Environment (Recommended)

**Best for:** Local testing with your own server

1. Set up a local PTT server:
   ```bash
   # Navigate to your server directory
   cd railway_server
   
   # Install dependencies
   npm install
   
   # Start server
   npm start
   ```

2. Update `environment.dart`:
   ```dart
   static Environment current = development;
   ```

3. Update development server URL if needed:
   ```dart
   static const Environment development = Environment(
     pttServerUrl: 'ws://localhost:3000', // Change port if needed
     // ... other configs
   );
   ```

4. Run your app:
   ```bash
   flutter run
   ```

---

### Option 2: Use Staging Environment

**Best for:** Testing with a deployed staging server

1. Set up a staging server (separate from production)
   - Deploy your PTT server to a staging URL
   - Example: `wss://ptt-staging.visionvivante.in`

2. Update `environment.dart`:
   ```dart
   static const Environment staging = Environment(
     pttServerUrl: 'wss://ptt-staging.visionvivante.in',
     // ... other configs
   );
   ```

3. Switch to staging:
   ```dart
   static Environment current = staging;
   ```

4. Run your app:
   ```bash
   flutter run
   ```

---

### Option 3: Create a Separate Test Account

**Best for:** Testing on production server without affecting real users

1. Keep environment as production:
   ```dart
   static Environment current = production;
   ```

2. Create test accounts in your system:
   - Test User 1: `test1@marispeak.com`
   - Test User 2: `test2@marispeak.com`

3. Test PTT between test accounts only
4. Keep test accounts separate from real user groups

---

## 🔍 Verifying Your Environment

### Check Environment at Runtime

Add this to any screen to see current environment:

```dart
import 'package:marispeaks/config/environment.dart';

// In your build method
Text('Environment: ${Environment.current.name}'),
Text('PTT Server: ${Environment.current.pttServerUrl}'),
```

### Check Logs

When the app starts, look for:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Environment: Development  <-- Your current environment
  PTT Server: ws://localhost:3000  <-- Server URL
  ...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Use Debug Widget

Import the debug widget:

```dart
import 'package:marispeaks/debug_ptt_status.dart';

// Add to your screen
FloatingActionButton(
  onPressed: () => showDialog(
    context: context,
    builder: (context) => PTTStatusDialog(),
  ),
  child: Icon(Icons.mic),
)
```

---

## 🏗️ Setting Up Your Development Server

### Using the Included Railway Server

Your project has a PTT server in `railway_server/` directory:

```bash
# Navigate to server directory
cd railway_server

# Install dependencies
npm install

# Start development server
npm start
```

The server will start on `ws://localhost:3000` by default.

### Configure Server Port

To change the port, edit `railway_server/server.js` (or similar):

```javascript
const PORT = process.env.PORT || 3000; // Change 3000 to your port
```

Then update `environment.dart`:

```dart
pttServerUrl: 'ws://localhost:3000', // Match your port
```

---

## 🧪 Testing Different Environments

### Test Matrix

| Environment | Server | Users | Purpose |
|-------------|--------|-------|---------|
| Development | Local | Test accounts | Active development |
| Staging | Staging | Test accounts | Pre-production QA |
| Production | Production | Real users | Live service |

### Testing Checklist

**Before Testing:**
- [ ] Verify correct environment is set
- [ ] Check server is running (if dev/staging)
- [ ] Check logs show correct server URL
- [ ] Use test accounts (not real users)

**During Testing:**
- [ ] WebSocket connects successfully
- [ ] Audio recording works
- [ ] Audio transmission works
- [ ] Audio playback works
- [ ] Group switching works
- [ ] Network reconnection works

**After Testing:**
- [ ] Switch back to production (if needed)
- [ ] Clean up test data
- [ ] Document any issues found

---

## ⚠️ Common Mistakes to Avoid

### ❌ Don't Do This:

1. **Testing on production with real users**
   ```dart
   // This affects REAL USERS!
   static Environment current = production;
   ```

2. **Forgetting to switch back to production**
   ```dart
   // Before app store release, always check:
   static Environment current = production; // ✅
   ```

3. **Hardcoding URLs in other files**
   ```dart
   // ❌ Don't do this in other files
   final url = "wss://ptt.visionvivante.in";
   
   // ✅ Do this instead
   final url = Environment.current.pttServerUrl;
   ```

---

## 🔒 Pre-Release Checklist

Before submitting to App Store/Play Store:

- [ ] Open `lib/config/environment.dart`
- [ ] Verify: `static Environment current = production;`
- [ ] Build release version: `flutter build ios --release`
- [ ] Test the release build
- [ ] Check logs for production server URL
- [ ] Submit to app store

---

## 📱 Build Commands

### Development Build
```bash
# Set environment to development first
flutter run --debug
```

### Staging Build
```bash
# Set environment to staging first
flutter build apk --release
flutter build ios --release
```

### Production Build
```bash
# Set environment to production first
flutter build apk --release --no-shrink
flutter build ios --release
```

---

## 🆘 Troubleshooting

### Problem: "Can't connect to PTT server"

**Check:**
1. Which environment are you using?
   ```dart
   print(Environment.current.name);
   print(Environment.current.pttServerUrl);
   ```

2. Is the server running?
   - Development: Check `localhost:3000`
   - Staging: Check staging server status
   - Production: Check production server status

3. Check firewall/network settings

### Problem: "Testing affects production users"

**Solution:**
1. Immediately switch to development:
   ```dart
   static Environment current = development;
   ```

2. Set up a local development server
3. Or use staging environment with test accounts

### Problem: "Forgot which environment I'm in"

**Solution:**
1. Check the console logs at app startup
2. Use the debug widget (`PTTStatusDialog`)
3. Add temporary UI indicator:
   ```dart
   if (!Environment.current.isProduction) {
     Container(
       color: Colors.red,
       child: Text('DEV MODE'),
     )
   }
   ```

---

## 🎯 Summary

### To Test Safely:

1. **Use Development Environment:**
   ```dart
   static Environment current = development;
   ```

2. **Run Local Server:**
   ```bash
   cd railway_server && npm start
   ```

3. **Test Your PTT:**
   ```bash
   flutter run
   ```

4. **Before Production Release:**
   ```dart
   static Environment current = production;
   ```

---

## 📚 Additional Resources

- **Environment Configuration:** `lib/config/environment.dart`
- **PTT Controller:** `lib/screens/ptt/websocket_ptt_controller.dart`
- **Server Code:** `railway_server/` directory
- **Debug Widget:** `lib/debug_ptt_status.dart`
- **Health Check Report:** `PTT_HEALTH_CHECK_REPORT.md`

---

## 💡 Pro Tips

1. **Visual Indicator:** Add a banner in development mode:
   ```dart
   if (Environment.current.isDevelopment) {
     MaterialBanner(
       content: Text('DEVELOPMENT MODE'),
       backgroundColor: Colors.orange,
     )
   }
   ```

2. **Environment-based Features:** Use environment checks:
   ```dart
   if (Environment.current.enableDebugFeatures) {
     // Show debug panel
   }
   ```

3. **Automated Switching:** Use build flavors (advanced):
   ```bash
   flutter run --flavor development
   flutter run --flavor production
   ```

---

**Need Help?** Check `PTT_HEALTH_CHECK_REPORT.md` for detailed testing instructions.
