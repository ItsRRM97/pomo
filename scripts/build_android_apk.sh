#!/usr/bin/env bash
# scripts/build_android_apk.sh - Build Android Debug APK for Android 16
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -d "/Users/rawshn/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
  export JAVA_HOME="/Users/rawshn/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

echo "=========================================="
echo "Building Pomo Android Debug APK..."
echo "=========================================="

echo "1. Getting dependencies and localizations..."
flutter pub get >/dev/null
flutter gen-l10n --arb-dir="lib/l10n/arb" >/dev/null

echo "2. Building APK (development flavor, debug build)..."
flutter build apk --debug --flavor development --target lib/main_development.dart

OUTPUT_APK="$ROOT/build/app/outputs/flutter-apk/app-development-debug.apk"
if [ -f "$OUTPUT_APK" ]; then
  echo "=========================================="
  echo "Successfully built Debug APK!"
  echo "APK Path: $OUTPUT_APK"
  echo "=========================================="
else
  echo "Error: Output APK not found after build."
  exit 1
fi
