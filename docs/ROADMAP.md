# Peeke CMMS-ERP Roadmap

**Last updated:** 2026-08-14  
**Status:** Foundations + multi-tenant onboarding **proven live**; **org roles & personal details** in progress; domain depth and offline field MVP next  
**Source of truth for platform priority and sequencing**

This roadmap advances **Peeke_CMMS-ERP** by importing high-value maintenance depth from mature **Peeke™** (`ArollSparrow/Peeke` + Supabase `ggvdgkaptatlfepgnjkx`), while following a **mobile-first, offline-first** strategy.

For Auth / Org / Platform / Payments checklist (P0–P3), see [IMPLEMENTATION_ROADMAP_AUTH_ORG_PLATFORM_PAYMENTS.md](IMPLEMENTATION_ROADMAP_AUTH_ORG_PLATFORM_PAYMENTS.md).  
Roles model: [ORG_ROLES_AND_DEPARTMENTS.md](ORG_ROLES_AND_DEPARTMENTS.md).

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

## Progress snapshot (2026-08-14)

| Track | Status |
|-------|--------|
| Multi-tenant orgs + RLS foundation | ✅ Live (3+ orgs; hard gate approve) |
| Tenant register → apply → pending → approve | ✅ |
| Team invite → Join your team → member | ✅ Proven |
| Org roles (CEO…Operator) + departments + personal details | 🟨 Schema + Team UI live; dept UI / work-loop gates next |
| Web (Cloudflare Pages) | ✅ Continuous deploy |
| Android / iOS platform folders + APK CI | ✅ |
| Branding (3-color Peeke Automation) | ✅ |
| Platform admin console (tenants, plans UI) | 🟨 Partial |
| **Marketing website (Option A)** — static Cloudflare Pages front door | ⬜ Planned (not started) |
| Domain modules (clients, work, inventory, …) | 🟨 Shells / partial depth |
| Offline engine (PowerSync) | ⬜ |
| Surgical Peeke™ import (`fault_codes`, rich jobs) | ⬜ / early |

---

## Marketing website (locked preference)

**Option A:** Simple **static marketing site** on Cloudflare Pages (separate from the app), linking into CMMS-ERP for **Apply / Sign in**.

| Surface | Purpose |
|---------|---------|
| Marketing site | Peeke Automation story, CMMS-ERP features, CTA → Apply |
| App (`peeke-cmms-erp.pages.dev`) | Auth, org apply (hard gate), full product |

Hard gate stays: strangers never get CMMS until Peeke Automation approves or opens a test window. Build when capacity allows — **does not block** Phase 1 mobile roles/work loops.

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

## Phase 0 – Foundations

**Goal:** Clean, tenant-scoped domain model + scaffolding for offline mobile.

### Flutter platform scaffolding (mobile-first)
- [x] Repo prepared for Android + iOS
- [x] `android/` and `ios/` in repo; web via Cloudflare Pages
- [x] APK workflow (Actions); iOS builds on demand

### Backend (Supabase – `tappfahlaiixctyliesz`)
- [x] Multi-tenancy model + org membership + invites
- [x] Auth paths: tenant register, member accept-invite, platform admin gate
- [x] Payment secret hardening (REVOKE + RPC)
- [x] Expanded org roles + departments seed + personal details columns
- [ ] Import critical surgical details from Peeke™ (`fault_codes`, job_parts, WO cost/SLA columns, …)
- [ ] Seed full fault-code reference data

### Flutter / Local
- [x] Feature-first Riverpod structure
- [x] Auth + organization membership + home shell
- [x] Team UI: role invite + edit personal details
- [ ] Fully tenant-scoped **local** schema + offline engine (**PowerSync** still to choose/wire)

**Deliverable status:** Onboarding + tenancy foundation **met**. Surgical domain model + offline schema **still open**.

---

## Phase 1 – Core Offline Mobile MVP (Android + iOS)

**Focus:** Field technicians. Full offline capability.

### Must-have features
- [x] Authentication + tenant membership (web-proven; mobile same codebase)
- [ ] Org switching polish + **role-based access** on work loops (Technician vs Supervisor/HoD)
- [ ] Local DB as source of truth
- [ ] Full offline Work Order flow (photos, fault codes, parts, labour, sync status)
- [ ] Basic Assets + Inventory offline
- [ ] Background sync + conflict handling
- [x] Secure Paystack pattern (server-side secrets)
- [ ] Real-device offline testing

**Deliverable:** Installable Android + iOS builds technicians can use fully offline — **not yet**.

---

## Phase 2 – Web Version + Hardening

**Office users & managers. Same Flutter codebase → Web.**

- [x] Web app live for office flows (registration, team, shells)
- [ ] Marketing static site (Option A) + CTAs into app
- [ ] Preventive Maintenance full depth (`pm_plan_spares`, SOP)
- [ ] Richer reporting & dashboards
- [ ] Security hardening (audit logs, optional MFA)
- [ ] Tenant plan limits / feature flags enforced
- [ ] Production email (SMTP/Resend) beyond built-in rate limits

---

## Phase 3 – Production Launch & Early Scale

- Closed beta with field technicians + office users
- Payment webhooks, usage metering, billing
- Advanced offline edge cases + data recovery
- App Store + Play Store (or enterprise distribution)
- Documentation & onboarding
- Soft launch → public launch

---

## Phase 4 – Growth & Optional Desktop (Ongoing)

- Additional ERP modules as demand appears
- Analytics & cross-tenant insights
- White-labeling / theming
- Possible AI (predictive maintenance)
- Windows desktop only if clear business need

---

## Related Docs

- [Implementation roadmap Auth/Org/Platform/Payments (P0–P3)](IMPLEMENTATION_ROADMAP_AUTH_ORG_PLATFORM_PAYMENTS.md)
- [Org roles & departments](ORG_ROLES_AND_DEPARTMENTS.md)
- [Foundation](FOUNDATION.md)
- [Implementation Strategy](IMPLEMENTATION_STRATEGY.md)
- [Invite member flow](INVITE_MEMBER_FLOW.md)
- [ADR 001 — BYO payments](adr/001-tenant-payments-byo.md)
- [ADR 002 — Platform owner vs tenant](adr/002-platform-owner-vs-tenant.md)

---

*Living roadmap. Update when priorities or imported scope change.*
