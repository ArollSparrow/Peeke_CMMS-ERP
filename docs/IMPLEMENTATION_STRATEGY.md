# Implementation strategy — Peeke CMMS-ERP (clean slate)

**Supabase:** `tappfahlaiixctyliesz` (Peeke CMMS-ERP)  
**Repo:** `ArollSparrow/Peeke_CMMS-ERP`  
**Started:** 2026-08-01  
**Last status update:** 2026-08-13

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

**Client fields:** name, site_name, location, contact, phone, email, billing_address, account_manager, account_type, sla_hours, location_coords, code, notes.

**System rules:** always **linked to a client** (`client_id`); denormalized client_name / client_site / client_location.

**System fields:** type, serial_number, model, capacity + unit, barcode, installation_date, registration_date, fuel tank, meters, notes.

**Workflow:** create client → Save & attach / client detail Attach → register system.

---

## Working rules

1. Every phase leaves a verifiable surface on `/home`.
2. Every domain slice passes the production benchmark.
3. Strategy may adapt order; never permanently lower the bar below production.

---

## Phases (clean-slate numbering)

### Phase 0 — Foundation ✅ DONE (plus live multi-tenant proof)

Auth, org create, RLS, home shell, branding.  
**2026-08:** Team invite → `/accept-invite` → member proven across two orgs.

### Phase 1 — Registration module 🟨 MOSTLY DONE

| Work | Status |
|------|--------|
| Schema field expansion | ✅ |
| Models + repository CRUD | ✅ |
| Client form (create/edit) | ✅ |
| System form (create/edit, client required) | ✅ |
| Client detail (Profile + Systems + Attach) | ✅ |
| System detail + delete | ✅ |
| Lists + search | ✅ |
| Registration hub | ✅ |
| Client contracts | deferred |
| GPS device capture | deferred |

### Phase 2 — Work loop 🟨 SHELL

Work requests → work orders → job card routes exist. Depth, fault codes, costs, **role-gated** approvals still open.

### Phases 3–8

Inventory, procurement, maintenance/ops, comms, BYO payments, differentiators — **shells present**, production parity open.

**Auth / Org / Platform / Payments (P0–P3):** see [IMPLEMENTATION_ROADMAP_AUTH_ORG_PLATFORM_PAYMENTS.md](IMPLEMENTATION_ROADMAP_AUTH_ORG_PLATFORM_PAYMENTS.md).

**Mobile-first phases:** see [ROADMAP.md](ROADMAP.md).

---

## Engineering rules

1. Tenant tables: `organization_id` + RLS.
2. No god service — repositories per feature.
3. Typed models — no `Map` in UI.
4. Lists paginate / search from first screens.
5. Secrets server-only.
6. Branches: `feature/*_grok`; merge after review.
7. Versioned migrations under `supabase/migrations/`.
8. Org create via SECURITY DEFINER RPC.
9. Home is the proof.
10. Benchmark before close.

---

## Success metrics

**Phase 0:** Met (auth, org, tenancy). Extended 2026-08 with live member multi-tenancy.

**Phase 1 (registration):** Client with strong fields; systems linked to clients; hub on home — **usable**; keep parity checklist open vs production.

**Next product priority:** Org **roles** for work loops, then work-loop depth and offline.
