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

Production `ArollSparrow/Peeke` is a **product reference only**.

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

**Exit criteria met:** Signed-in user creates/uses org and lands on gated home shell.  
**First tenant:** Peeke Automation (`peeke-automation-cmms-erp`).

### Phase 1 — Master data (IN PROGRESS)

Clients, systems (assets), basic lists with pagination + Gloss patterns.

| Work | Status |
|------|--------|
| Tables `clients`, `systems` + RLS | ✅ migration `003` |
| Typed models + repositories | ✅ |
| List + create UI | ✅ |
| Home nav | ✅ |
| Detail screens / client↔system link | next |

### Phase 2 — Work loop

Work requests → work orders (state machine, roles, badges).

### Phase 3 — Inventory

Parts, transactions, issue/receive.

### Phase 4 — Procurement

PR → PO → receive → GRN (controls: submit ≠ approve).

### Phase 5 — Maintenance & ops

PM plans, downtime, reports.

### Phase 6 — Comms

In-app notifications; Cloudflare Workers → Slack (Activepieces optional).

### Phase 7 — BYO payments

`org_payment_credentials`, webhook edge, invoice status (ADR 001).

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
7. **Migrations** only via Supabase `apply_migration` / versioned SQL in repo under `supabase/migrations/`.
8. **Org create** via SECURITY DEFINER RPC (avoid INSERT…RETURNING RLS chicken-and-egg).

---

## Repo layout (target)

```
lib/
  app/                 bootstrap, router, theme
  core/                result, errors, constants
  design/              gloss tokens + widgets
  features/
    auth/
    org/
    clients/           (phase 1)
    ...
  infra/
    supabase/
supabase/migrations/   mirrored SQL
docs/
```

---

## Success metric for Phase 0

> Create account → create organization → land on empty home with org name — no production code copied. **Met 2026-08-02.**
