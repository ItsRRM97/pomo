#!/usr/bin/env bash
# scripts/setup.sh - Automated onboarding and prerequisite setup script
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=========================================="
echo "Starting Pomo Environment Setup..."
echo "=========================================="

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: 'flutter' command not found in PATH."
  echo "Please install the Flutter SDK (>=3.6.0) and add it to your PATH."
  exit 1
fi

FLUTTER_VER="$(flutter --version | head -n 1)"
echo "Detected Flutter version: ${FLUTTER_VER}"

echo "1. Fetching pub dependencies..."
flutter pub get

echo "2. Generating localization files (AppLocalizations)..."
flutter gen-l10n --arb-dir="lib/l10n/arb"

echo "=========================================="
echo "Setup complete! You can now run the app:"
echo "  flutter run --flavor development -d macos --target lib/main_development.dart"
echo "=========================================="
