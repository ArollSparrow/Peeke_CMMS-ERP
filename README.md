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

## Locked decisions

- Multi-tenant: every org isolated via RLS
- **BYO Paystack** for tenant customer payments ([ADR 001](docs/adr/001-tenant-payments-byo.md))
- Riverpod-first, Gloss UI, **Cloudflare Pages** for web
- **Mobile-first offline** (Android + iOS primary) — [Roadmap](docs/ROADMAP.md)

## Backend

| Field | Value |
|-------|--------|
| Supabase project | **Peeke CMMS-ERP** |
| Ref | `tappfahlaiixctyliesz` |
| URL | `https://tappfahlaiixctyliesz.supabase.co` |
| Region | `eu-central-1` |

## Platforms (Mobile-first)

| Priority | Platform | Notes |
|----------|----------|-------|
| 1 | **Android + iOS** | Primary field apps — generate once and commit |
| 2 | **Web** | Office users (CI already builds this) |
| 3 | Desktop | Optional later |

### Option A — Computer (recommended)

```bash
git clone https://github.com/ArollSparrow/Peeke_CMMS-ERP.git
cd Peeke_CMMS-ERP
bash scripts/setup_platforms.sh
git add android ios && git commit -m "chore: add Android and iOS platform folders" && git push
```

### Option B — GitHub Codespaces (phone / browser)

1. Open the repo → green **Code** → **Codespaces** → **Create codespace on main**  
   (or rebuild the existing one so it picks up `.devcontainer`)
2. Wait for **postCreateCommand** to finish (installs Flutter + generates platforms).  
   First boot can take 3–8 minutes.
3. In the terminal:

```bash
export PATH="$HOME/flutter/bin:$PATH"
ls android ios          # should list both folders
git add android ios
git commit -m "chore: add Android and iOS platform folders"
git push
```

If platforms were not created automatically:

```bash
bash scripts/codespace_bootstrap.sh
```

> Codespaces is usable for this one-time generation, but day-to-day mobile work is much better on a real machine.

## Deploy (Web)

Workflow: `.github/workflows/deploy-cloudflare-pages.yml`  
Secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `SUPABASE_ANON_KEY`

## Docs

- **[Roadmap](docs/ROADMAP.md)**
- [Implementation strategy](docs/IMPLEMENTATION_STRATEGY.md)
- [Foundation](docs/FOUNDATION.md)
- [ADR 001 — BYO payments](docs/adr/001-tenant-payments-byo.md)
