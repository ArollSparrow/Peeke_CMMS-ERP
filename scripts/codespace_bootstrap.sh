#!/usr/bin/env bash
# Bootstrap Flutter + platform folders inside GitHub Codespaces / devcontainers.
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="${HOME}/flutter/bin:${PATH}"

echo "=== Peeke Codespace bootstrap ==="

if ! command -v flutter >/dev/null 2>&1; then
  echo "→ Installing Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${HOME}/flutter"
  export PATH="${HOME}/flutter/bin:${PATH}"
  # Persist for future shells
  if ! grep -q 'flutter/bin' "${HOME}/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "${HOME}/.bashrc"
  fi
fi

echo "→ Flutter version:"
flutter --version

echo "→ Enabling web (safe if already enabled)..."
flutter config --enable-web >/dev/null 2>&1 || true

echo "→ flutter pub get"
flutter pub get

if [ ! -d android ] || [ ! -d ios ]; then
  echo "→ Generating android / ios / web platform folders..."
  flutter create . --project-name peeke_cmms_erp --platforms=android,ios,web
  echo "→ Platforms generated. Commit them when ready:"
  echo "   git add android ios && git commit -m 'chore: add Android and iOS platform folders' && git push"
else
  echo "→ android/ and ios/ already present — skipping create"
fi

echo "=== Bootstrap complete ==="
echo "Run web:  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080"
