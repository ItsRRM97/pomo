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

# Flutter 3.44+ ships a stub flutter_service_worker.js that unregisters itself and
# reloads the page. Load the app directly via flutter_bootstrap instead.
perl -i -0pe 's/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[^}]+\}\s*\}\);/_flutter.loader.load();/s' deploy/focus/flutter_bootstrap.js

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
sed "s/focus-pwa-v1/focus-pwa-${VERSION}/" web/pwa_service_worker.js > deploy/focus/pwa_service_worker.js

echo "Web build ready at deploy/focus"
