# Peeke CMMS-ERP — Foundation notes (clean slate)

**Repo:** `ArollSparrow/Peeke_CMMS-ERP`  
**Started:** 2026-07 / 2026-08  
**Last status update:** 2026-08-13  
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
| Tenant payments | **BYO** — tenants connect **their own** Paystack. See [ADR 001](adr/001-tenant-payments-byo.md) |
| Platform SaaS fee (optional later) | Peeke’s own merchant account — separate from tenant operational payments |
| Edge / web hosting | Cloudflare Pages + Workers preferred |
| Automation | Prefer Cloudflare Workers for webhooks; Activepieces optional |
| UI | Gloss design system; landing strict 3-color (sky / navy / teal) |
| Branches | Agent work uses `*_grok` |
| Product bar | Production Peeke = minimum domain completeness |
| Member vs tenant | Invite → `/accept-invite`; tenant → Register → create org |

## Supabase (clean slate)

| Field | Value |
|-------|--------|
| Name | **Peeke CMMS-ERP** |
| Project ref / id | `tappfahlaiixctyliesz` |
| Region | `eu-central-1` |
| API URL | `https://tappfahlaiixctyliesz.supabase.co` |

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

0. Foundation: auth, org context, design system, repo layout — **done**  
1. Master data: clients, systems — **mostly done**  
2. Work requests → work orders — **shell**  
3. Inventory — **shell**  
4. Procurement — **shell**  
5. Maintenance / operations / reports — **shell**  
6. Comms  
7. Tenant BYO payments + invoices — **partial**  
8. Attachments (Storage), QR, hierarchy, budgets  

Detail: [IMPLEMENTATION_ROADMAP_AUTH_ORG_PLATFORM_PAYMENTS.md](IMPLEMENTATION_ROADMAP_AUTH_ORG_PLATFORM_PAYMENTS.md) · [ROADMAP.md](ROADMAP.md)

## Connectors

- GitHub (`ArollSparrow`)
- Supabase — **Peeke CMMS-ERP** (`tappfahlaiixctyliesz`)
- Cloudflare Pages — `peeke-cmms-erp.pages.dev`

## Status

Foundation complete. Multi-tenant onboarding (tenant + team member) proven live. Domain depth and offline field MVP are the open workstreams.
