#!/usr/bin/env bash
# Generate Flutter platform folders for mobile-first development.
# Safe to re-run: flutter create will not overwrite existing customizations carelessly,
# but prefer running once and then committing android/ + ios/.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "→ Generating platforms: android, ios, web"
flutter create . --project-name peeke_cmms_erp --platforms=android,ios,web

echo "→ flutter pub get"
flutter pub get

echo ""
echo "Done. Next:"
echo "  flutter run -d android   # or an emulator id"
echo "  flutter run -d ios       # requires macOS + Xcode"
echo "  flutter run -d chrome"
echo ""
echo "Recommended: commit the generated android/ and ios/ folders so the team shares the same baseline."
