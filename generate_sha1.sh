#!/bin/bash

echo "🔑 SHA-1 Certificate Generator"
echo "=============================="

# Check if keytool is available
if ! command -v keytool &> /dev/null; then
    echo "❌ keytool not found. Please install Java JDK"
    exit 1
fi

echo "📱 Generating SHA-1 certificate for Android..."
echo ""

# Generate SHA-1 from debug keystore
echo "🔑 Debug SHA-1 Certificate:"
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

echo ""
echo "🔑 SHA-256 Certificate (also add this if needed):"
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA-256

echo ""
echo "📋 Instructions:"
echo "1. Copy the SHA-1 certificate from above"
echo "2. Go to Firebase Console: https://console.firebase.google.com/project/huruchat-2c9f9/settings"
echo "3. Add the SHA-1 fingerprint to your Android app"
echo "4. Download fresh google-services.json"
echo "5. Replace android/app/google-services.json"