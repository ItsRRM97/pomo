#!/usr/bin/env bash
# scripts/verify.sh - Unified Quality Assurance and Verification Suite
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=========================================="
echo "Running Pomo Verification Suite..."
echo "=========================================="

echo "1. Synchronizing dependencies and localizations..."
flutter pub get >/dev/null
flutter gen-l10n --arb-dir="lib/l10n/arb" >/dev/null

echo "2. Checking Dart code formatting..."
if ! dart format --output=none --set-exit-if-changed lib/ test/ scripts/; then
  echo "Error: Code formatting check failed. Please run 'dart format lib/ test/ scripts/' to fix."
  exit 1
fi

echo "3. Running static analysis (very_good_analysis)..."
if ! flutter analyze --no-fatal-infos; then
  echo "Error: Static analysis reported issues. Please fix all lints before submitting."
  exit 1
fi

echo "4. Executing automated regression test suite..."
if [ -d "test" ] && [ "$(ls -A test/*.dart test/**/*.dart 2>/dev/null | wc -l)" -gt 0 ]; then
  flutter test --flavor development
else
  echo "Notice: No test files detected yet in test/. Skipping test step."
fi

echo "=========================================="
echo "Verification Suite Passed Successfully!"
echo "=========================================="
