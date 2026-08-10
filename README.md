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

### Example (registration review branch)

After a **green** Actions run on `feature/registration_module_grok`:

- Branch alias: https://feature-registration-module-grok.peeke-cmms-erp.pages.dev  
- Or open **Actions → Deploy Web → Cloudflare Pages → latest run → Summary** for the exact deployment URL.

> Preview URLs only exist **after** CI has deployed that branch. Pushing code alone is not enough if the workflow never ran for that branch.

## Locked decisions

- Multi-tenant: every org isolated via RLS
- **BYO Paystack** for tenant customer payments ([ADR 001](docs/adr/001-tenant-payments-byo.md))
- Riverpod-first, Gloss UI, **Cloudflare Pages** for web preview + production
- **Mobile-first offline** (Android + iOS primary) — see [Roadmap](docs/ROADMAP.md)

## Backend

| Field | Value |
|-------|--------|
| Supabase project | **Peeke CMMS-ERP** |
| Ref | `tappfahlaiixctyliesz` |
| URL | `https://tappfahlaiixctyliesz.supabase.co` |
| Region | `eu-central-1` |

## Deploy setup (one-time)

GitHub Actions workflow: `.github/workflows/deploy-cloudflare-pages.yml`

**Triggers**

- Every **push** to any branch (including `feature/*_grok`) → Pages deploy  
- **Pull requests** into `main` → preview deploy  
- **workflow_dispatch** → manual run  
- `main` → production environment on project `peeke-cmms-erp`

Add **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|--------|
| `CLOUDFLARE_API_TOKEN` | Token with **Account → Cloudflare Pages → Edit** |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account id |
| `SUPABASE_ANON_KEY` | Anon key from Supabase project `tappfahlaiixctyliesz` |

Optional variable: `SUPABASE_URL` (defaults to clean-slate URL in the workflow).

## Run locally

```bash
git clone https://github.com/ArollSparrow/Peeke_CMMS-ERP.git
cd Peeke_CMMS-ERP
flutter create . --project-name peeke_cmms_erp
flutter pub get
flutter run -d chrome
```

## Docs

- **[Roadmap](docs/ROADMAP.md)** ← Phase 0–4 strategy (mobile-first + surgical import from Peeke™)
- [Implementation strategy](docs/IMPLEMENTATION_STRATEGY.md)
- [Foundation](docs/FOUNDATION.md)
- [ADR 001 — BYO payments](docs/adr/001-tenant-payments-byo.md)
