#!/bin/bash

echo "🔍 APNs Diagnostics for PTT Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check 1: Certificate file exists
echo "1️⃣ Checking APNs certificate file..."
if [ -f "AuthKey_AC7HTJC42H.p8" ]; then
    echo "   ✅ AuthKey_AC7HTJC42H.p8 found"
    ls -lh AuthKey_AC7HTJC42H.p8
else
    echo "   ❌ AuthKey_AC7HTJC42H.p8 NOT FOUND!"
    echo "   This is critical - APNs cannot work without it"
fi
echo ""

# Check 2: Network connectivity to Apple
echo "2️⃣ Testing network connectivity to Apple APNs..."
echo "   Testing sandbox server..."
if timeout 5 bash -c "</dev/tcp/api.sandbox.push.apple.com/443" 2>/dev/null; then
    echo "   ✅ Can reach api.sandbox.push.apple.com:443"
else
    echo "   ❌ Cannot reach api.sandbox.push.apple.com:443"
    echo "   Your server has network/firewall issues!"
fi

echo "   Testing production server..."
if timeout 5 bash -c "</dev/tcp/api.push.apple.com/443" 2>/dev/null; then
    echo "   ✅ Can reach api.push.apple.com:443"
else
    echo "   ❌ Cannot reach api.push.apple.com:443"
fi
echo ""

# Check 3: Server configuration
echo "3️⃣ Checking server.js configuration..."
if [ -f "server.js" ]; then
    echo "   Checking production mode setting..."
    if grep -q "production: true" server.js; then
        echo "   ⚠️  FOUND: production: true"
        echo "      This is WRONG for TestFlight! Should be false."
    elif grep -q "production: false" server.js; then
        echo "   ✅ FOUND: production: false (correct for TestFlight)"
    else
        echo "   ❓ Could not determine production mode setting"
    fi
    
    echo "   Checking APNs topic..."
    if grep -q "voip-ptt" server.js; then
        echo "   ⚠️  FOUND: voip-ptt topic"
        echo "      For standard VoIP, use: .voip (not .voip-ptt)"
    elif grep -q '\.voip"' server.js; then
        echo "   ✅ FOUND: .voip topic (correct)"
    fi
    
    echo "   Checking pushType..."
    if grep -q 'pushType.*pushtotalk' server.js; then
        echo "   ⚠️  FOUND: pushType: 'pushtotalk'"
        echo "      For standard VoIP, use: 'voip' (not 'pushtotalk')"
    elif grep -q 'pushType.*voip' server.js; then
        echo "   ✅ FOUND: pushType: 'voip' (correct)"
    fi
else
    echo "   ❌ server.js not found in current directory"
fi
echo ""

# Check 4: Node modules
echo "4️⃣ Checking Node.js APNs module..."
if npm list @parse/node-apn &>/dev/null; then
    echo "   ✅ @parse/node-apn is installed"
    npm list @parse/node-apn | grep node-apn
else
    echo "   ❌ @parse/node-apn is NOT installed"
    echo "   Run: npm install @parse/node-apn"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 SUMMARY & RECOMMENDATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "For TestFlight, your server.js should have:"
echo ""
echo "  production: false          ← SANDBOX mode"
echo "  topic: '...voip'           ← NOT .voip-ptt"
echo "  pushType: 'voip'           ← NOT 'pushtotalk'"
echo ""
echo "After fixing, restart your server:"
echo "  pm2 restart ptt_vision"
echo ""
