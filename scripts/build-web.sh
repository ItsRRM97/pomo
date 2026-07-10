#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Install Flutter on Vercel when not present locally in CI
if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
  flutter config --enable-web
  flutter precache --web
fi

flutter pub get
flutter gen-l10n
flutter build web \
  --release \
  --no-wasm-dry-run \
  --base-href=/focus/ \
  --target lib/main_production.dart

rm -rf deploy/focus
mkdir -p deploy/focus
cp -R build/web/. deploy/focus/

echo "Web build ready at deploy/focus"
