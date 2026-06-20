#!/bin/bash
# Test script for Phase 9 URL scheme configuration
# Tests the scalecloud://config URL scheme with various parameter combinations

echo "========================================"
echo "Phase 9 URL Scheme Testing Script"
echo "========================================"
echo ""

# Example credentials (Base64 encoded)
EMAIL="user@example.com"
PASSWORD="password123"
ENCODED_EMAIL=$(echo -n "$EMAIL" | base64)
ENCODED_PASSWORD=$(echo -n "$PASSWORD" | base64)

# Example Anisette server URL
ANISETTE_URL="http://100.64.0.1:6969"
ENCODED_ANISETTE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ANISETTE_URL', safe=''))")

echo "Test Credentials:"
echo "  Email: $EMAIL"
echo "  Password: $PASSWORD"
echo "  Email (Base64): $ENCODED_EMAIL"
echo "  Password (Base64): $ENCODED_PASSWORD"
echo ""
echo "Test Anisette Server:"
echo "  URL: $ANISETTE_URL"
echo "  URL (encoded): $ENCODED_ANISETTE"
echo ""
echo "========================================"
echo ""

# Test 1: Anisette only
echo "Test 1: Configure Anisette server only"
URL1="scalecloud://config?anisette=$ENCODED_ANISETTE"
echo "URL: $URL1"
echo "Command: xcrun simctl openurl booted \"$URL1\""
echo ""
read -p "Press Enter to execute Test 1..."
xcrun simctl openurl booted "$URL1"
echo "✓ Test 1 sent"
echo ""

# Test 2: Credentials only
echo "Test 2: Configure Apple ID credentials only"
URL2="scalecloud://config?appleID=$ENCODED_EMAIL&password=$ENCODED_PASSWORD"
echo "URL: $URL2"
echo "Command: xcrun simctl openurl booted \"$URL2\""
echo ""
read -p "Press Enter to execute Test 2..."
xcrun simctl openurl booted "$URL2"
echo "✓ Test 2 sent"
echo ""

# Test 3: Combined (full configuration)
echo "Test 3: Configure both Anisette and credentials"
URL3="scalecloud://config?anisette=$ENCODED_ANISETTE&appleID=$ENCODED_EMAIL&password=$ENCODED_PASSWORD"
echo "URL: $URL3"
echo "Command: xcrun simctl openurl booted \"$URL3\""
echo ""
read -p "Press Enter to execute Test 3..."
xcrun simctl openurl booted "$URL3"
echo "✓ Test 3 sent"
echo ""

echo "========================================"
echo "Testing complete!"
echo ""
echo "Expected behavior:"
echo "1. App should receive URL and parse parameters"
echo "2. Configuration should be stored in UserDefaults/Keychain"
echo "3. Setup flow should skip configured screens on next launch"
echo ""
echo "To verify:"
echo "1. Check Xcode console for '[Config]' log messages"
echo "2. Restart app and verify setup flow skips configured screens"
echo "3. Check UserDefaults for anisettePreConfigured/credentialsPreConfigured flags"
echo "========================================"
