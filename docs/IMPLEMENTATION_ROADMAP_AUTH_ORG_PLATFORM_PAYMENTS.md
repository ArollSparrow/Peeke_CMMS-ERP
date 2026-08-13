# Implementation Roadmap — Registration, Auth, Org, Platform, Payments

**Last updated:** 2026-08-13  
**Supabase:** `tappfahlaiixctyliesz`  
**Live proof:** multi-tenant orgs + first team **member** (Join your team path)

*Aligned with comparative progress report, multi-tenancy strategy, and verified live usage.*

---

## End product picture

| Pillar | User-facing outcome | Non-negotiables |
|--------|---------------------|-----------------|
| **Registration** | Confirm work email → create tenant → register clients/systems | Email ownership proven before org create |
| **Auth** | Sign-in, recovery, invite set-password, session across restarts | No secrets in client; clear errors; later MFA for owners |
| **Org** | Tenant boundary, roles, invites, org switch | RLS on every domain table; elevated approvals when multi-user |
| **Platform** | Peeke Automation admins manage tenants & plans | `is_platform_admin()` only; audited support access later |
| **Payments** | Paystack BYO + platform billing | **Secrets never reach Flutter**; webhooks service-role only |

**Design:** Landing + launcher stay strict 3-color logo system (sky `#D3EFFD`, navy `#272A6D`, teal `#55AAAC`). Post-login may add *status* hues without changing that base.

**Two entry paths (locked):**

| Path | Who | Flow |
|------|-----|------|
| **Tenant** | Org owner | Register → confirm email → Create organization → Sign in |
| **Team member** | Invitee | Accept invitation → `/accept-invite` (name + password) → member of inviting org |

Members must **not** use tenant Register on the invite email.

---

## Status legend

| Mark | Meaning |
|------|--------|
| ✅ | Done and proven in production path / live data |
| 🟨 | Partial — shell, schema, or UI exists; not finished |
| ⬜ | Not started / deferred |

---

## P0 — Security foundation

| # | Item | Status | Notes |
|---|------|--------|-------|
| P0.1 | Remove payment secret exposure | ✅ | Column REVOKE + `set_organization_payment_secrets` RPC; client must not `.select()` secrets |
| P0.2 | Isolation test script | 🟨 | Script exists; re-run formally with Tentons **member** vs Peeke Systems |
| P0.3 | Friendly errors app-wide | 🟨 | Auth/registration improved; ~remaining raw exceptions in domain modules |

**P0 outcome:** Secrets not readable by ordinary members; invite/tenant separation enforced in app + DB (`create_organization` blocks pure invitees).

---

## P1 — Trust & onboarding

| # | Item | Status | Notes |
|---|------|--------|-------|
| P1.1 | Auth / registration gate polish | ✅ | Branded login/register, create-org, confirm-email UX, 3-color theme |
| P1.2 | Org invites + membership management | ✅ | Edge `invite-org-member`, pending invites, revoke, remove member, `/accept-invite`, `accept_pending_org_invites` |
| P1.3 | Elevate WO/WR approval by role | ⬜ | `OrgCapabilities.requireElevatedForApproval` still false; roles only owner/admin/member |

**P1 outcome (proven live):**

- Peeke Systems — owner  
- Tentons Systems — owner + **member** (`mulandijoseph72@gmail.com`)  
- Multi-tenancy with real membership, not only empty orgs  

**P1 remaining:** richer org **roles** (technician, supervisor, store, …) and wire them to work loops (user priority next).

---

## P2 — Platform & billing product

| # | Item | Status | Notes |
|---|------|--------|-------|
| P2.1 | Plan enforcement (`trialing` / `past_due` → app gate and/or RLS) | 🟨 | Subscription tables + platform UI to **assign** plans exist; **no hard gate** blocking tenant app when past_due |
| P2.2 | Edge Functions: charge + webhook verify (service role only) | 🟨 | Payment settings + secret RPC path exist; **no production charge/webhook Edge Function** locked for tenant Paystack yet |
| P2.3 | Tenant offboarding (soft delete + retention) | ⬜ | Not designed in product UI |
| P2.4 | Platform admin UX (branded, no secret display) | 🟨 | Platform home, tenants list, subscriptions assign, platform Paystack settings exist; polish + secret non-display rules still improve |

**What P2 has already touched**

- Platform console isolated from tenant CMMS (`/platform` vs `/home`)
- `platform_admins` gate
- Tenant list + subscription assign (plan, status, amounts)
- Platform Paystack keys (BYO pattern mirrored for SaaS collection)
- Organization subscription row on org create (default trial)

**What P2 still needs**

- Enforce plan status in app (and optionally RLS)
- Real webhook-verified charges
- Soft-delete / retention policy
- Production email (Custom SMTP / Resend) — testing stays on built-in ~2/hour

---

## P3 — Domain depth (comparative + ROADMAP surgical import)

| # | Item | Status | Notes |
|---|------|--------|-------|
| P3.1 | Clients/systems field parity vs production | 🟨 | Registration hub, client/system CRUD, client-linked systems largely present; field naming / full parity checklist still open |
| P3.2 | Work module depth (WR → WO → job card) | 🟨 | Feature modules and routes exist; not production-parity workflow |
| P3.3 | Maintenance surgical import from Peeke™ | 🟨 | Maintenance hub, PM plans, history, downtime screens exist; `fault_codes`, rich job_parts, cost/SLA columns incomplete |
| P3.4 | Offline mobile (PowerSync) | ⬜ | Android/iOS folders + APK workflow exist; offline engine not wired as source of truth |

**What P3 has already touched (shell / partial)**

| Module | Present | Gap |
|--------|---------|-----|
| Clients / systems / registration | Lists, forms, hub | Full production field parity, GPS |
| Work | Requests, orders, job card routes | Lifecycle, costs, fault codes, approvals by role |
| Inventory | Hub, parts | Offline issue/receive, role gates |
| Procurement | Vendors, POs | Depth vs production |
| Maintenance / ops | Plans, jobs, history, downtime, ops record | Surgical Peeke™ import |
| Payments (tenant BYO) | Settings UI, transactions list | Secret-safe select, webhooks |

---

## Cross-cut: engineering already in place

| Area | Status |
|------|--------|
| Web deploy (Cloudflare Pages) | ✅ automatic on `main` |
| Android debug APK (Actions) | ✅ on-demand / path triggers |
| iOS platform folders | ✅ source in repo; builds on demand |
| Branding + launcher | ✅ |
| Riverpod feature-first layout | ✅ |
| RLS multi-tenant model | ✅ foundation; continuous audit |

---

## Recommended sequence from here

1. **Org roles + capabilities** (extends P1.3) — technician / supervisor / storekeeper, etc.  
2. **Wire one work loop** to those roles (P3.2)  
3. **Formal isolation test** with Tentons member (finish P0.2)  
4. **fault_codes + maintenance surgical columns** (P3.3 / Phase 0 remainder in `ROADMAP.md`)  
5. **Plan gate + production email** (P2.1 + mail)  
6. **Offline engine** when field trials start (P3.4 / Phase 1 mobile)

---

## Related docs

- [ROADMAP.md](ROADMAP.md) — mobile-first phases 0–4  
- [IMPLEMENTATION_STRATEGY.md](IMPLEMENTATION_STRATEGY.md) — clean-slate phase order + benchmark  
- [INVITE_MEMBER_FLOW.md](INVITE_MEMBER_FLOW.md) — member vs tenant  
- [FOUNDATION.md](FOUNDATION.md)  
- ADRs under `docs/adr/`
