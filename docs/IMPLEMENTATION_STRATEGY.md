# Implementation strategy — Peeke CMMS-ERP (clean slate)

**Supabase:** `tappfahlaiixctyliesz` (Peeke CMMS-ERP)  
**Repo:** `ArollSparrow/Peeke_CMMS-ERP`  
**Started:** 2026-08-01

## Goal

Ship a multi-tenant CMMS/ERP platform where:

- Peeke is the **platform**
- Each **organization** is isolated (RLS + `organization_id`)
- Tenants **BYO Paystack** for their own customer payments
- Code is Riverpod-first, feature-modular, Gloss UI

---

## Product benchmark (locked)

**Production `ArollSparrow/Peeke` + Supabase project `ggvdgkaptatlfepgnjkx` are the permanent product benchmark.**

| Rule | Meaning |
|------|--------|
| **Never ship inferior** | A clean-slate feature is not “done” if it is weaker than production on fields, relationships, or core workflow. |
| **Reference, not fork** | Inspect schema, screens, and flows in production; **rebuild** in Riverpod + RLS. Do not copy monolith/`Map`/god-service patterns. |
| **Parity checklist** | Before closing a phase slice: compare field set, required links (e.g. system → client), list columns, and primary user path against production. |
| **Improve, don’t strip** | Architecture, multi-tenancy, and UI may improve; domain completeness must meet or beat the previous app. |
| **When uncertain** | Open production table columns + registration screens first; then implement. |

### Master-data benchmark (Phase 1)

From production registration (client → attach system):

**Client fields (minimum parity):** name, site_name, location, contact, phone, email, billing_address, account_manager, account_type, sla_hours, location_coords (GPS later).

**System rules:** always **linked to a client** (`client_id`); denormalized client_name / client_site / client_location for lists.

**System fields (minimum parity):** type, serial_number, model, capacity + capacity_unit, barcode, installation_date, registration_date; generator extras (fuel tank, meters, operation_type) as follow-ons.

**Workflow:** create/select client → attach system on that client (no orphan systems in the happy path).

Remaining Phase 1 work is measured against this list, not against the thin scaffold that shipped first.

---

## Working rules

1. **Every phase must leave a verifiable surface on the home/dashboard.**  
   KPIs, module tiles, phase checklist on `/home`. No phase is “done” until `/home` reflects it.

2. **Every domain slice must pass the production benchmark** (section above).

3. Strategy may adapt **order** when UX feedback requires it; it must not permanently lower the bar below production.

---

## Phases

### Phase 0 — Foundation ✅ DONE

| Work | Deliverable |
|------|-------------|
| Org + auth schema | `organizations`, `profiles`, `organization_members`, RLS helpers |
| Flutter scaffold | Feature folders, Riverpod, Supabase init, router shell |
| Design tokens | Minimal Gloss colors + page scaffold |
| Auth screens | Login / register / session gate |
| Org bootstrap | `create_organization` RPC + owner membership |

**Exit criteria met:** Signed-in user creates/uses org and lands on gated home.  
**First tenant:** Peeke Automation (`peeke-automation-cmms-erp`).

### Phase 1 — Master data + home dashboard (IN PROGRESS)

| Work | Status |
|------|--------|
| Tables `clients`, `systems` + RLS | ✅ migrations `003`–`004` |
| Field expansion toward production | ✅ partial (`004` + richer create forms) |
| System **requires** client | ✅ create path |
| Typed models + repositories | ✅ |
| Home dashboard | ✅ |
| Full client form (account/SLA/GPS) | next |
| Full system form (barcode, dates, meters) | next |
| Client detail + systems tab + Attach flow | next |

**How to verify:** `/home` KPIs; Clients create with site/location; Systems create only with client selected.

### Phase 2 — Work loop

Work requests → work orders (state machine, roles, badges).  
**Benchmark:** production WO list, detail, status transitions, client/system selector.

### Phase 3 — Inventory

Parts, transactions, issue/receive.  
**Benchmark:** production inventory screens and stock rules.

### Phase 4 — Procurement

PR → PO → receive → GRN (submit ≠ approve).  
**Benchmark:** production procurement controls.

### Phase 5 — Maintenance & ops

PM plans, downtime, reports.  
**Benchmark:** production maintenance/ops records and reports.

### Phase 6 — Comms

In-app notifications; Cloudflare Workers → Slack (Activepieces optional).

### Phase 7 — BYO payments

`org_payment_credentials`, webhook edge, invoice status (ADR 001).  
*(Platform capability beyond single-tenant production — still no weaker operational payments UX than needed.)*

### Phase 8 — Differentiator

Storage attachments, QR, hierarchy, budgets.

---

## Engineering rules

1. **Every tenant table** has `organization_id` + RLS using `is_org_member` / role helpers.
2. **No god service** — repositories per feature.
3. **Typed models** — no `Map` in UI.
4. **Lists paginate** from the first screen.
5. **Secrets server-only** (Paystack secret, service role).
6. **Branches:** `feature/*_grok` for agent work; merge after your review.
7. **Migrations** only via Supabase `apply_migration` / versioned SQL under `supabase/migrations/`.
8. **Org create** via SECURITY DEFINER RPC.
9. **Home is the proof** — phase visible on `/home`.
10. **Benchmark before close** — production field/relationship/workflow parity for that slice.

---

## Repo layout (target)

```
lib/
  app/                 bootstrap, router, theme
  core/                result, errors, constants
  design/              gloss tokens + widgets
  features/
    auth/
    org/               home dashboard
    clients/           phase 1 (clients + systems)
    ...
  infra/
    supabase/
supabase/migrations/
docs/
```

---

## Success metrics

**Phase 0:** Create account → create organization → home with org name. **Met 2026-08-02.**

**Phase 1:** Home KPIs live; client has production-class fields; every new system is linked to a client; list subtitles show client · type · serial (parity path, not a stripped toy).
