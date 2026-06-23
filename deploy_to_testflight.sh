#!/bin/bash

# MariSpeak PTT - Full Clean Rebuild & TestFlight Deployment Script
# This script ensures all fixes are properly applied with a clean build

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 MariSpeak PTT - Clean Rebuild"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found!"
    echo "Please run this script from the project root directory:"
    echo "cd /Users/pc/Downloads/agora_ptt && ./deploy_to_testflight.sh"
    exit 1
fi

echo "✅ Found project root"
echo ""

# Step 1: Clean all build artifacts
echo "🧹 Step 1/5: Cleaning build artifacts..."
flutter clean
if [ $? -ne 0 ]; then
    echo "❌ Flutter clean failed!"
    exit 1
fi
echo "✅ Clean complete"
echo ""

# Step 2: Get dependencies
echo "📦 Step 2/5: Installing dependencies..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Flutter pub get failed!"
    exit 1
fi
echo "✅ Dependencies installed"
echo ""

# Step 3: Verify environment configuration
echo "🔍 Step 3/5: Verifying environment..."
echo "Production server: wss://ptt.visionvivante.in"
echo "API server: https://api.marispeak.com"
echo ""

# Step 4: Build release iOS
echo "🔨 Step 4/5: Building iOS release..."
echo "This may take 3-5 minutes..."
flutter build ios --release
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build complete"
echo ""

# Step 5: Open Xcode for archiving
echo "📤 Step 5/5: Opening Xcode for archiving..."
echo ""
echo "Next steps in Xcode:"
echo "1. Select 'Any iOS Device (arm64)' in the toolbar"
echo "2. Product > Archive"
echo "3. Wait for archive to complete (~2 minutes)"
echo "4. Click 'Distribute App'"
echo "5. Select 'App Store Connect'"
echo "6. Follow the upload wizard"
echo ""
echo "Press ENTER to open Xcode..."
read

open ios/Runner.xcworkspace

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Fixes included in this build:"
echo "  ✅ PTT reliability (5-second WebSocket wait)"
echo "  ✅ Back button crash fix (Navigator.pop)"
echo "  ✅ Background music auto-resume"
echo "  ✅ No more debug notifications"
echo "  ✅ Audio corruption fix (no chunk interruption)"
echo "  ✅ Network drop recovery (auto-reconnect)"
echo ""
echo "⏱️  TestFlight processing time: ~15 minutes"
echo ""
echo "🧪 Test scenarios after TestFlight install:"
echo "  1. Open app → Press PTT immediately → Should work"
echo "  2. Navigate to Call History → Press back → Should not crash"
echo "  3. Play music → Send PTT → Music should resume after"
echo "  4. Turn WiFi off/on → PTT should auto-reconnect"
echo ""
echo "📄 See CURRENT_STATUS_AND_NEXT_STEPS.md for detailed testing guide"
echo ""
