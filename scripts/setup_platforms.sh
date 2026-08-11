#!/usr/bin/env bash
# Generate Flutter platform folders for mobile-first development.
# Works on a local machine or inside a Codespace after Flutter is installed.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found on PATH."
  echo "In Codespaces run:  bash scripts/codespace_bootstrap.sh"
  echo "Or install Flutter: https://docs.flutter.dev/get-started/install"
  exit 1
fi

echo "→ Generating platforms: android, ios, web"
flutter create . --project-name peeke_cmms_erp --platforms=android,ios,web

echo "→ flutter pub get"
flutter pub get

echo ""
echo "Done. Next:"
echo "  git add android ios"
echo "  git commit -m 'chore: add Android and iOS platform folders'"
echo "  git push"
echo ""
echo "  flutter run -d android   # or emulator"
echo "  flutter run -d ios       # macOS + Xcode"
echo "  flutter run -d chrome"
