# Peeke CMMS-ERP — Foundation notes (clean slate)

**Repo:** `ArollSparrow/Peeke_CMMS-ERP`  
**Started:** 2026-07 / 2026-08  
**Not a fork of production** — rebuild from first principles.

## Product posture

- Multi-tenant CMMS / light ERP.
- Peeke provides the **platform** (app, workflows, data model).
- Each **organization** is an independent business on the platform.

## Product benchmark (locked)

**`ArollSparrow/Peeke` (code) and Supabase `ggvdgkaptatlfepgnjkx` (schema/data model) are the permanent product benchmark.**

- Clean-slate work must **not ship domain features weaker** than production (fields, relationships, primary workflows).
- Use production as a **checklist and design reference**, not as code to paste.
- Architecture must be **better** (Riverpod modules, org RLS, no god service) while product depth meets or exceeds the previous app.
- See [IMPLEMENTATION_STRATEGY.md](IMPLEMENTATION_STRATEGY.md) for the full parity rule and Phase 1 master-data checklist.

## Locked decisions

| Topic | Decision |
|-------|----------|
| State management | Riverpod-first |
| Backend | Supabase (Auth, DB, RLS, Realtime, Storage, Edge Functions) |
| Tenant payments | **BYO** — tenants connect **their own** Paystack (then optional Stripe). Platform does not hold tenant client funds. See [ADR 001](adr/001-tenant-payments-byo.md) |
| Platform SaaS fee (optional later) | Peeke’s own merchant account — separate from tenant operational payments |
| Edge / web hosting | Cloudflare Pages + Workers preferred |
| Automation | Prefer Cloudflare Workers for webhooks; Activepieces optional |
| UI | Gloss design system as single kit |
| Branches | Agent work uses `*_grok` |
| Product bar | Production Peeke = minimum domain completeness |

## Supabase (clean slate)

| Field | Value |
|-------|--------|
| Name | **Peeke CMMS-ERP** |
| Project ref / id | `tappfahlaiixctyliesz` |
| Region | `eu-central-1` |
| Status | `ACTIVE_HEALTHY` |
| API URL | `https://tappfahlaiixctyliesz.supabase.co` |
| DB host | `db.tappfahlaiixctyliesz.supabase.co` |
| Org | `peekopsys@gmail.com's Org` (`nrfdlrvqhrgsfzmmyxuu`) |

**Separate from production:** Peeke™ (`ggvdgkaptatlfepgnjkx`) remains live production and is not written to by this greenfield app.

## Explicit non-copies from production

- No monolithic `SupabaseService`.
- No full-table list fetches without pagination plan.
- No shipping tables/screens without RLS.
- No secret keys in the Flutter client.
- No `Map` as the UI model layer.

## Explicit *must* learn from production

- Field sets and required relationships (e.g. **system → client**).
- Registration order (client then system).
- Operational workflows (WO states, procurement controls, inventory rules).
- What power users already rely on day-to-day.

## Phase order (high level)

0. Foundation: auth, org context, design system, repo layout  
1. Master data: clients, systems (parity with production registration)  
2. Work requests → work orders  
3. Inventory  
4. Procurement  
5. Maintenance / operations / reports  
6. Comms  
7. Tenant BYO payments + invoices  
8. Attachments (Storage), QR, hierarchy, budgets  

## Connectors in use for this workspace

- GitHub (`ArollSparrow`)
- Supabase — project **Peeke CMMS-ERP** (`tappfahlaiixctyliesz`)
- Cloudflare (`Jkiaimorogo@gmail.com's Account`)

## Status

Phase 0 complete. Phase 1 in progress with production field alignment (`004`) and client-linked systems.
