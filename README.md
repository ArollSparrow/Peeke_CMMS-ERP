# Peeke CMMS-ERP

**Peeke™** CMMS-ERP — clean-slate multi-tenant platform (Riverpod + Supabase).

| Repo | Role |
|------|------|
| [`ArollSparrow/Peeke`](https://github.com/ArollSparrow/Peeke) | Production (reference only) |
| **`ArollSparrow/Peeke_CMMS-ERP`** | Clean slate (this repo) |

## Locked decisions

- Multi-tenant: every org isolated via RLS
- **BYO Paystack** for tenant customer payments ([ADR 001](docs/adr/001-tenant-payments-byo.md))
- Riverpod-first, Gloss UI, Cloudflare-oriented edge

## Backend

| Field | Value |
|-------|--------|
| Supabase project | **Peeke CMMS-ERP** |
| Ref | `tappfahlaiixctyliesz` |
| URL | `https://tappfahlaiixctyliesz.supabase.co` |
| Region | `eu-central-1` |

Migration **001** applied: `organizations`, `profiles`, `organization_members` + RLS helpers.

## Phase 0 (in progress)

- [x] Implementation strategy
- [x] Org/auth schema + RLS
- [x] Flutter scaffold (auth, org create, home shell)
- [ ] Platform folders (`android`/`ios`/`web`) via local `flutter create .`
- [ ] End-to-end test on device/web

## Run locally

```bash
git clone https://github.com/ArollSparrow/Peeke_CMMS-ERP.git
cd Peeke_CMMS-ERP
flutter create . --project-name peeke_cmms_erp   # generates platform folders once
flutter pub get
flutter run -d chrome   # or your device
```

Keys default to the clean-slate project in `lib/infra/supabase/supabase_env.dart` (anon only).

## Docs

- [Implementation strategy](docs/IMPLEMENTATION_STRATEGY.md)
- [Foundation](docs/FOUNDATION.md)
- [ADR 001 — BYO payments](docs/adr/001-tenant-payments-byo.md)
