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
| **Preview** (PRs / other branches) | `https://<branch-or-hash>.peeke-cmms-erp.pages.dev` |

> First successful deploy is required before the production URL serves the app. See **Deploy setup** below.

## Locked decisions

- Multi-tenant: every org isolated via RLS
- **BYO Paystack** for tenant customer payments ([ADR 001](docs/adr/001-tenant-payments-byo.md))
- Riverpod-first, Gloss UI, **Cloudflare Pages** for web preview + production

## Backend

| Field | Value |
|-------|--------|
| Supabase project | **Peeke CMMS-ERP** |
| Ref | `tappfahlaiixctyliesz` |
| URL | `https://tappfahlaiixctyliesz.supabase.co` |
| Region | `eu-central-1` |

## Deploy setup (one-time)

GitHub Actions workflow: `.github/workflows/deploy-cloudflare-pages.yml`

Add **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|--------|
| `CLOUDFLARE_API_TOKEN` | Token with **Account → Cloudflare Pages → Edit** |
| `CLOUDFLARE_ACCOUNT_ID` | `642cb1f526f3f6bcb29f4a94f262fc48` |
| `SUPABASE_ANON_KEY` | Anon/publishable key from Supabase project `tappfahlaiixctyliesz` |

Optional variable: `SUPABASE_URL` (defaults to clean-slate URL in the workflow).

Then push to `main` or run **Actions → Deploy Web → Cloudflare Pages → Run workflow**.

- **Production:** every push to `main`
- **Preview:** every pull request (unique preview URL in the Actions log / deployment)

## Run locally

```bash
git clone https://github.com/ArollSparrow/Peeke_CMMS-ERP.git
cd Peeke_CMMS-ERP
flutter create . --project-name peeke_cmms_erp
flutter pub get
flutter run -d chrome
```

## Docs

- [Implementation strategy](docs/IMPLEMENTATION_STRATEGY.md)
- [Foundation](docs/FOUNDATION.md)
- [ADR 001 — BYO payments](docs/adr/001-tenant-payments-byo.md)
