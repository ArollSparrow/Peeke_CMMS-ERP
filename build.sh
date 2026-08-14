#!/bin/bash
set -e

# Used by Cloudflare Pages (and local CI) to produce build/web.
git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter_sdk
export PATH="$PWD/flutter_sdk/bin:$PATH"

flutter config --enable-web
flutter pub get

# Platform folders may be missing if repo was scaffolded via API only.
if [ ! -d web ]; then
  flutter create . --project-name peeke_cmms_erp --platforms=web
fi

# Peeke branding icons for PNG fallbacks (SVG favicon is already in web/).
mkdir -p web/icons
ICON="assets/branding/peeke_icon.png"
if [ -f "$ICON" ]; then
  cp "$ICON" web/favicon.png
  cp "$ICON" web/icons/Icon-192.png
  cp "$ICON" web/icons/Icon-512.png
  cp "$ICON" web/icons/Icon-maskable-192.png
  cp "$ICON" web/icons/Icon-maskable-512.png
fi

# Keep committed favicon.svg / index.html / manifest.json intact.
flutter build web --release --no-tree-shake-icons \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://tappfahlaiixctyliesz.supabase.co}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

# Ensure favicon assets survive into the published folder
if [ -f web/favicon.svg ]; then
  cp web/favicon.svg build/web/favicon.svg
fi
if [ -f web/favicon.png ]; then
  cp web/favicon.png build/web/favicon.png
fi
mkdir -p build/web/icons
if [ -d web/icons ]; then
  cp -n web/icons/* build/web/icons/ 2>/dev/null || true
fi

# SPA fallback for go_router deep links on Cloudflare Pages
printf '/*    /index.html   200\n' > build/web/_redirects
