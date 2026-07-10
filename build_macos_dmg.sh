#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_PATH="$PROJECT_ROOT/Pomo.dmg"
APP_PATH_FLAVOR="$PROJECT_ROOT/build/macos/Build/Products/Release-production/Pomo.app"
APP_PATH_DEFAULT="$PROJECT_ROOT/build/macos/Build/Products/Release/Pomo.app"

export PATH="$HOME/homebrew/bin:$PATH"

echo "--> Checking Xcode developer directory and license status..."
if [ -z "$DEVELOPER_DIR" ]; then
  for xcode_path in /Applications/Xcode*.app/Contents/Developer; do
    if [ -d "$xcode_path" ]; then
      export DEVELOPER_DIR="$xcode_path"
      echo "--> Automatically using detected Xcode path: $DEVELOPER_DIR"
      break
    fi
  done
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: Xcode ('xcodebuild') is not available in the current developer path."
  echo "Please switch your active developer tool directory to Xcode:"
  echo "   sudo xcode-select -s /Applications/Xcode-26.6.0.app/Contents/Developer"
  exit 1
fi

if xcodebuild -sdk macosx -version 2>&1 | grep -i -q "license agreements"; then
  echo "ERROR: You have not agreed to the Xcode license agreements."
  echo "Please run the following commands in terminal to accept the license and set the default Xcode path:"
  echo "   sudo xcodebuild -license accept"
  echo "   sudo xcode-select -s /Applications/Xcode-26.6.0.app/Contents/Developer"
  exit 1
fi

if ! [ -e "/Library/Developer/PrivateFrameworks/CoreSimulator.framework" ] || xcodebuild -sdk macosx -version 2>&1 | grep -i -q -E "runFirstLaunch|CoreSimulator"; then
  echo "ERROR: Xcode first-launch system frameworks (CoreSimulator) are not installed yet."
  echo "Please run the following command in terminal to install Apple's required system frameworks:"
  echo "   sudo xcodebuild -runFirstLaunch"
  exit 1
fi

flutter config --no-enable-swift-package-manager >/dev/null 2>&1 || true
flutter build macos --release --flavor production -t lib/main_production.dart

if [ -d "$APP_PATH_FLAVOR" ]; then
  APP_PATH="$APP_PATH_FLAVOR"
elif [ -d "$APP_PATH_DEFAULT" ]; then
  APP_PATH="$APP_PATH_DEFAULT"
else
  echo "ERROR: Build finished but Pomo.app was not found in Release-production or Release."
  exit 1
fi
echo "--> Found compiled app at: $APP_PATH"

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
