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

flutter build web --release --no-tree-shake-icons \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://tappfahlaiixctyliesz.supabase.co}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

# SPA fallback for go_router deep links on Cloudflare Pages
printf '/*    /index.html   200\n' > build/web/_redirects
