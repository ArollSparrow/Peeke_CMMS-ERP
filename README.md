# Peeke CMMS-ERP

**Peeke™** CMMS-ERP — clean-slate multi-tenant platform (Riverpod + Supabase).

| Repo | Role |
|------|------|
| [`ArollSparrow/Peeke`](https://github.com/ArollSparrow/Peeke) | Production (reference only) |
| **`ArollSparrow/Peeke_CMMS-ERP`** | Clean slate (this repo) |

## Live URLs (Cloudflare Pages)

| Environment | URL |
|-------------|-----|
| **Production** (`main`) | https://peeke-cmms-erp.pages.dev |
| **Branch preview** | `https://<branch-with-slashes-as-hyphens>.peeke-cmms-erp.pages.dev` |
| **Unique deploy** | Printed in **Actions** job summary / Cloudflare deployment (hash URL) |

> Preview URLs only exist **after** CI has deployed that branch.

## Locked decisions

- Multi-tenant: every org isolated via RLS
- **BYO Paystack** for tenant customer payments ([ADR 001](docs/adr/001-tenant-payments-byo.md))
- Riverpod-first, Gloss UI, **Cloudflare Pages** for web preview + production
- **Mobile-first offline** (Android + iOS primary, Web secondary) — see [Roadmap](docs/ROADMAP.md)

## Backend

| Field | Value |
|-------|--------|
| Supabase project | **Peeke CMMS-ERP** |
| Ref | `tappfahlaiixctyliesz` |
| URL | `https://tappfahlaiixctyliesz.supabase.co` |
| Region | `eu-central-1` |

## Platforms (Mobile-first)

| Priority | Platform | Status | Notes |
|----------|----------|--------|-------|
| 1 | **Android** | Generate locally | Primary field app |
| 1 | **iOS** | Generate locally | Primary field app |
| 2 | **Web** | Auto-created by `build.sh` / CI | Office users |
| 3 | Desktop | Optional later | Only if demand appears |

### One-time platform generation (required for Android + iOS)

The repo is intentionally lib-first. Native project folders are created with Flutter:

```bash
git clone https://github.com/ArollSparrow/Peeke_CMMS-ERP.git
cd Peeke_CMMS-ERP

# Generate Android + iOS + Web platform folders (safe if some already exist)
flutter create . --project-name peeke_cmms_erp --platforms=android,ios,web

flutter pub get
```

Then run on a device/emulator:

```bash
# Android
flutter run -d android

# iOS (macOS + Xcode required)
flutter run -d ios

# Web
flutter run -d chrome
```

> After the first `flutter create`, commit the generated `android/` and `ios/` folders (recommended) so the whole team shares the same native baseline. `.gitignore` already excludes build artifacts, keystores, Pods, etc.

## Deploy setup (Web / Cloudflare Pages)

GitHub Actions workflow: `.github/workflows/deploy-cloudflare-pages.yml`

**Triggers:** push to any branch, PRs into `main`, `workflow_dispatch`. `main` → production.

**Required secrets:**

| Secret | Value |
|--------|--------|
| `CLOUDFLARE_API_TOKEN` | Token with **Account → Cloudflare Pages → Edit** |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account id |
| `SUPABASE_ANON_KEY` | Anon key from Supabase project `tappfahlaiixctyliesz` |

Optional: `SUPABASE_URL` (defaults to the clean-slate URL in the workflow).

## Docs

- **[Roadmap](docs/ROADMAP.md)** ← Phase 0–4 strategy (mobile-first + surgical import from Peeke™)
- [Implementation strategy](docs/IMPLEMENTATION_STRATEGY.md)
- [Foundation](docs/FOUNDATION.md)
- [ADR 001 — BYO payments](docs/adr/001-tenant-payments-byo.md)
