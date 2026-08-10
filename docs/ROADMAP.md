# Peeke CMMS-ERP Roadmap

**Last updated:** 2026-08-10  
**Status:** Phase 0 starting  
**Source of truth for platform priority and sequencing**

This roadmap advances **Peeke_CMMS-ERP** by importing the high-value “surgical” maintenance depth already proven in the mature **Peeke™** project (`ArollSparrow/Peeke` + Supabase `ggvdgkaptatlfepgnjkx`), while strictly following a **mobile-first, offline-first** strategy.

---

## Platform Priority (Locked)

| Priority | Platform | Role | Offline Capability | When to Build |
|----------|----------|------|--------------------|---------------|
| **1 (Primary)** | Android + iOS | Field technicians | Full offline-first | Phase 1 (core) |
| **2 (Secondary)** | Web | Office users & managers | Limited (PWA-style) | Phase 2 |
| **3 (Optional)** | Desktop / Windows | Office workstations or kiosks | Good | Phase 3 or later |

**Guiding principles**
- Android + iOS native apps are the heart of the product — that is where real offline power lives.
- Web is valuable for office staff but should never be the primary offline experience.
- Desktop is optional — only build it when there is a concrete business need.
- Local database remains the source of truth on mobile.
- Keep secrets server-side.
- Test offline scenarios on real devices early and often.
- Multi-tenancy (`organization_id` + RLS) is non-negotiable from day one.

---

## Surgical Import Strategy (from Peeke™ → CMMS-ERP)

### Must import early (Phase 0–1)
- `fault_codes` table + FKs
- Richer maintenance job model (`maintenance_jobs` / evolved `maintenance_records` + `job_parts`)
- Core work-order cost, SLA, client-acceptance, and attendance fields
- Enriched work-request fields (inspection, root cause, spares)
- Basic downtime enrichment (fault code, hour meters, ongoing flag)

### Import in Phase 2
- Full PM spares + SOP depth (`pm_plan_spares`, richer templates)
- Multi-stage WO approvals & client acceptance flow
- Deeper procurement patterns (if needed by office users)
- Automation / notification patterns

### Defer or adapt
- Chat, announcements, Slack/Activepieces specifics
- Very heavy denormalised text fields that fight the cleaner SaaS multi-tenant design
- Anything that conflicts with the cleaner organization / subscription model already in CMMS-ERP

---

## Phase 0 – Foundations (1–2 weeks)

**Goal:** Clean, tenant-scoped domain model + local schema ready for offline mobile.

### Backend (Supabase – Peeke CMMS-ERP `tappfahlaiixctyliesz`)
1. Finalize multi-tenancy — harden RLS on every table.
2. Import critical surgical details from Peeke™:
   - Create `fault_codes` + seed core codes (generator / inverter / pump categories).
   - Evolve `maintenance_records` **or** introduce `maintenance_jobs` + `job_parts` (recommended for clarity).
   - Add key columns to `work_orders`: `fault_code_id`, `sla_due_at`, `client_acceptance_status`, `parts_cost`, `labour_cost`, `total_cost` (generated), `technicians_attendance` (jsonb), `department`, linked job reference.
   - Enrich `work_requests` with inspection / root-cause / spares fields.
   - Add `pm_plan_spares`.
   - Enrich `downtime_events` with fault_code, hour meters, ongoing flag, resolution notes.
3. Write ordered migrations (apply via Supabase).
4. Seed minimal reference data (fault codes, roles, one demo org).

### Flutter / Local
- Confirm feature-first Riverpod project structure.
- Design fully tenant-scoped local schema that mirrors the critical tables above.
- Choose and wire offline engine (**PowerSync recommended**).
- Auth + organization membership + switching skeleton.

**Deliverable:** Domain model locked, migrations applied, local schema designed, offline engine decided.

---

## Phase 1 – Core Offline Mobile MVP (Android + iOS) (7–11 weeks)

**Focus exclusively on field technicians. Full offline capability.**

### Must-have features
- Authentication + tenant membership + org switching
- Local DB as source of truth
- **Full offline Work Order flow**:
  - View / create / update / status transitions
  - Photos, notes, signatures, barcode scanning
  - Structured fault code selection
  - Parts usage (internal/external) with basic cost capture
  - Labour hours + simple rate snapshot
- Basic Assets (`systems` / `clients`) and Inventory (view + issue) — offline capable
- Background sync + conflict handling + clear online/offline/sync status indicators
- Role-based access (Technician vs Supervisor/Admin)
- Secure Paystack (server-side only)
- Real-device testing in low/no connectivity

### Import prioritisation inside Phase 1

| Priority | Peeke™ Detail | Why in Phase 1 |
|----------|---------------|----------------|
| P0 | `fault_codes` | Structured logging from day 1 |
| P0 | Richer job / maintenance logging | Cost + service history |
| P1 | Core WO lifecycle + costs | Real technician workflow |
| P1 | Work Request → WO conversion basics | Field request capture |
| P2 | Basic PM trigger awareness | Can wait for Phase 2 polish |

**Deliverable:** Installable Android + iOS builds that technicians can use fully offline for core work-order and basic inventory work.

---

## Phase 2 – Web Version + Hardening (4–6 weeks)

**Office users & managers. Same Flutter codebase → Web.**

- Web version for supervisors, procurement, managers
- Preventive Maintenance scheduling (full `pm_plans` + `pm_plan_spares` + SOP templates)
- Richer reporting & dashboards (larger screens)
- Photo/attachment gallery improvements
- Security hardening (refined RLS, audit logs, optional MFA)
- Cloudflare (custom domains, WAF, Workers if needed)
- Performance tuning + monitoring
- Tenant plan limits / feature flags (leverage existing subscription tables)

**Additional imports from Peeke™:** Full multi-stage WO approvals & client acceptance, deeper procurement if required, automation hooks.

---

## Phase 3 – Production Launch & Early Scale (4–7 weeks)

- Closed beta with real field technicians (Android + iOS) + office users (Web)
- Payment webhooks, usage metering, billing
- Advanced offline edge cases + data recovery tools
- App Store + Play Store (or enterprise distribution)
- Documentation & onboarding
- Soft launch → public launch
- Monitor sync reliability, crash rates, and support tickets

---

## Phase 4 – Growth & Optional Desktop (Ongoing)

- Additional ERP modules as real demand appears
- Analytics & cross-tenant insights
- White-labeling / theming
- Possible AI features (predictive maintenance using the rich fault + meter history)
- **Windows desktop only if clear business need**
- Continuous improvement driven by field feedback

---

## Related Docs

- [Foundation](FOUNDATION.md)
- [Implementation Strategy](IMPLEMENTATION_STRATEGY.md)
- [ADR 001 — BYO payments](adr/001-tenant-payments-byo.md)
- [ADR 002 — Platform owner vs tenant](adr/002-platform-owner-vs-tenant.md)

---

*This document is the living roadmap. Update it when priorities or imported scope change.*
