#!/bin/bash

# PTT WebSocket Connection Test Script
# This script tests connectivity to your PTT WebSocket server

echo "🔍 Testing PTT WebSocket Connection..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SERVER="wss://ptt.visionvivante.in"
echo "📡 Target Server: $SERVER"
echo ""

# Check if wscat is installed
if ! command -v wscat &> /dev/null; then
    echo "⚠️  wscat is not installed"
    echo "   Install it using: npm install -g wscat"
    echo ""
    echo "   Alternative test using curl:"
    echo "   curl -i -N -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: test' https://ptt.visionvivante.in"
    exit 1
fi

echo "✅ wscat is installed"
echo ""

# Test WebSocket connection
echo "🔌 Attempting WebSocket connection..."
echo "   (This will timeout after 5 seconds)"
echo ""

timeout 5s wscat -c "$SERVER" <<EOF
{"type":"ping"}
EOF

CONNECTION_RESULT=$?

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $CONNECTION_RESULT -eq 0 ]; then
    echo "✅ WebSocket connection SUCCESSFUL"
    echo "   Your PTT server is reachable"
elif [ $CONNECTION_RESULT -eq 124 ]; then
    echo "⏱️  Connection timeout (might be normal)"
    echo "   Server may be waiting for proper auth"
elif [ $CONNECTION_RESULT -eq 1 ]; then
    echo "❌ WebSocket connection FAILED"
    echo "   Possible issues:"
    echo "   - Server is down"
    echo "   - Network connectivity problem"
    echo "   - Firewall blocking WebSocket"
fi

echo ""
echo "🔍 Additional Tests:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check DNS resolution
echo "🌐 DNS Resolution:"
HOST=$(echo "$SERVER" | sed 's|wss://||' | sed 's|/.*||')
nslookup "$HOST" > /dev/null 2>&1
DNS_RESULT=$?
if [ $DNS_RESULT -eq 0 ]; then
    echo "   ✅ DNS resolves correctly"
    nslookup "$HOST" | grep -A2 "Name:" | tail -2
else
    echo "   ❌ DNS resolution failed"
fi

echo ""

# Check HTTPS connectivity (WebSocket upgrade)
echo "🔒 HTTPS Connectivity:"
HTTP_URL=$(echo "$SERVER" | sed 's|wss://|https://|')
curl -I -s --max-time 5 "$HTTP_URL" > /dev/null 2>&1
HTTP_RESULT=$?
if [ $HTTP_RESULT -eq 0 ]; then
    echo "   ✅ HTTPS connection successful"
elif [ $HTTP_RESULT -eq 28 ]; then
    echo "   ⏱️  Connection timeout"
else
    echo "   ⚠️  HTTPS connection issue (code: $HTTP_RESULT)"
fi

echo ""

# Check internet connectivity
echo "🌍 Internet Connectivity:"
ping -c 2 8.8.8.8 > /dev/null 2>&1
PING_RESULT=$?
if [ $PING_RESULT -eq 0 ]; then
    echo "   ✅ Internet connection active"
else
    echo "   ❌ No internet connection"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
if [ $CONNECTION_RESULT -eq 0 ] || [ $CONNECTION_RESULT -eq 124 ]; then
    echo "   ✅ PTT WebSocket server appears to be functional"
    echo "   ✅ You can test PTT in your app"
else
    echo "   ⚠️  PTT WebSocket connection issues detected"
    echo "   🔧 Check your server status"
    echo "   🔧 Verify network connectivity"
fi

echo ""
echo "🚀 To test PTT in the app:"
echo "   1. flutter run"
echo "   2. Sign in with two accounts on different devices"
echo "   3. Open a chat between the accounts"
echo "   4. Press and hold the PTT button"
echo "   5. Check logs for: '✅ Connected as [userId]'"
echo ""
