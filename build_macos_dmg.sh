#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_PATH="$PROJECT_ROOT/Pomo.dmg"
APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Release/Pomo.app"

export PATH="$HOME/homebrew/bin:$PATH"

echo "--> Checking Xcode installation..."
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: Xcode ('xcodebuild') is not available in the current developer path."
  echo "Because native Flutter macOS apps compile Swift and Objective-C files (`Runner.xcworkspace`),"
  echo "the full Xcode application (~12GB) is required."
  echo ""
  echo "How to resolve:"
  echo "1. Download and install Xcode from the Mac App Store (or https://developer.apple.com/xcode/)."
  echo "2. Switch the command-line developer directory from CommandLineTools to Xcode.app:"
  echo "   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  echo "3. Accept the Xcode license agreements:"
  echo "   sudo xcodebuild -runFirstLaunch"
  echo "4. Re-run this script: ./build_macos_dmg.sh"
  exit 1
fi

echo "--> Building native macOS application (Pomo.app)..."
flutter build macos --release -t lib/main_production.dart

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Build finished but $APP_PATH was not found."
  exit 1
fi

echo "--> Removing old .dmg if present..."
rm -f "$DMG_PATH"

echo "--> Generating Pomo.dmg in project folder..."
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --volname "Pomo" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Pomo.app" 175 190 \
    --hide-extension "Pomo.app" \
    --app-drop-link 425 190 \
    "$DMG_PATH" \
    "$APP_PATH" || {
      echo "--> create-dmg UI styling skipped or errored; falling back to hdiutil..."
      rm -f "$DMG_PATH"
      hdiutil create -volname "Pomo" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
    }
else
  hdiutil create -volname "Pomo" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
fi

echo ""
echo "=========================================================================="
echo " SUCCESS! .dmg generated at:"
echo "   $DMG_PATH"
echo "=========================================================================="
echo "Double-click Pomo.dmg in Finder or install it directly via:"
echo "   open \"$DMG_PATH\""
