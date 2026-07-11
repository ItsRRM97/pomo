#!/usr/bin/env bash
# scripts/build_android_release_apk.sh - Build Android Release APK for Android 16
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -d "/Users/rawshn/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
  export JAVA_HOME="/Users/rawshn/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

echo "=========================================="
echo "Building Pomo Android Release APK..."
echo "=========================================="

echo "1. Getting dependencies and localizations..."
flutter pub get >/dev/null
flutter gen-l10n --arb-dir="lib/l10n/arb" >/dev/null

echo "2. Building APK (development flavor, release build)..."
flutter build apk --release --flavor development --target lib/main_development.dart

OUTPUT_APK="$ROOT/build/app/outputs/flutter-apk/app-development-release.apk"
if [ -f "$OUTPUT_APK" ]; then
  echo "=========================================="
  echo "Successfully built Release APK!"
  echo "APK Path: $OUTPUT_APK"
  echo "=========================================="
else
  echo "Error: Output APK not found after build."
  exit 1
fi
