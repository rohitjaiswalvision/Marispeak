#!/bin/bash

# Script to help fix the PTT group mismatch issue

echo "🔍 Finding problematic joinGroup calls..."
echo ""

echo "📁 File: lib/main.dart"
echo "Lines that switch back to own ID:"
grep -n "joinGroup(currentUser)" lib/main.dart 2>/dev/null || echo "  Not found"
echo ""

echo "📁 File: lib/screens/home/CustomBottomSection.dart"
echo "Lines that switch back to own ID:"
grep -n "joinGroup(currentUser.userId)" lib/screens/home/CustomBottomSection.dart 2>/dev/null || echo "  Not found"
echo ""

echo "📁 All joinGroup calls in the project:"
grep -rn "joinGroup(" lib/ --include="*.dart" | head -20
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RECOMMENDED FIX:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Comment out these lines:"
echo "1. lib/main.dart - lines calling joinGroup(currentUser)"
echo "2. lib/screens/home/CustomBottomSection.dart - lines 1796, 1807"
echo ""
echo "These lines switch users back to their own ID after PTT,"
echo "which prevents communication!"
echo ""
echo "After fixing, both users will stay in the shared chat group"
echo "and will be able to hear each other's PTT messages."
echo ""
