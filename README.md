# Peeke CMMS-ERP

**Peeke™** CMMS-ERP — clean-slate Riverpod app (greenfield workspace).

> GitHub repo name: `Peeke_CMMS-ERP` (spaces are not allowed in repository names).

## Purpose

New development baseline. Production app [`ArollSparrow/Peeke`](https://github.com/ArollSparrow/Peeke) is a **product reference only** — not a code dump.

| Repo | Role |
|------|------|
| `ArollSparrow/Peeke` | Production CMMS-ERP |
| **`ArollSparrow/Peeke_CMMS-ERP`** | Clean-slate platform (this repo) |

## Locked product decisions

- **Multi-tenant platform** — each organization is independent.
- **Tenant payments = bring your own (BYO)** — tenants connect **their own** Paystack account (Stripe optional later). Peeke does **not** take or split their customer funds. See [`docs/adr/001-tenant-payments-byo.md`](docs/adr/001-tenant-payments-byo.md).
- **Riverpod-first**, Supabase backend, Gloss UI, Cloudflare-oriented edge/web.
- Agent branches: `*_grok`.

## Docs

- [`docs/FOUNDATION.md`](docs/FOUNDATION.md) — stack and phase order
- [`docs/adr/001-tenant-payments-byo.md`](docs/adr/001-tenant-payments-byo.md) — payments ADR

## Status

Foundation documentation started. Scaffold and schema next.
