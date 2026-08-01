# Peeke CMMS-ERP — Foundation notes (clean slate)

**Repo:** `ArollSparrow/Peeke_CMMS-ERP`  
**Started:** 2026-07 / 2026-08  
**Not a fork of production** — product reference only from `ArollSparrow/Peeke`.

## Product posture

- Multi-tenant CMMS / light ERP.
- Peeke provides the **platform** (app, workflows, data model).
- Each **organization** is an independent business on the platform.

## Locked decisions

| Topic | Decision |
|-------|----------|
| State management | Riverpod-first |
| Backend | Supabase (Auth, DB, RLS, Realtime, Storage, Edge Functions) |
| Tenant payments | **BYO** — tenants connect **their own** Paystack (then optional Stripe). Platform does not hold tenant client funds. See [ADR 001](adr/001-tenant-payments-byo.md) |
| Platform SaaS fee (optional later) | Peeke’s own merchant account — separate from tenant operational payments |
| Edge / web hosting direction | Cloudflare (Pages + Workers) preferred for web + webhooks |
| Automation | Supabase events → Activepieces → Slack / email (app writes domain state) |
| UI | Gloss design system as single kit |
| Branches | Agent work uses `*_grok` |

## Explicit non-copies from production

- No monolithic `SupabaseService`.
- No full-table list fetches without pagination plan.
- No shipping tables/screens without RLS.
- No secret keys in the Flutter client.

## Phase order (high level)

0. Foundation: auth, org context, design system, repo layout  
1. Master data: clients, systems  
2. Work requests → work orders  
3. Inventory  
4. Procurement  
5. Maintenance / operations / reports  
6. Comms  
7. Tenant BYO payments + invoices  
8. Attachments (Storage), QR, hierarchy, budgets  

## Connectors in use for this workspace

- GitHub (`ArollSparrow`)
- Supabase (when project linked)
- Cloudflare (when configured)

## Status

Foundation docs started. Flutter scaffold and first schema migrations next.
