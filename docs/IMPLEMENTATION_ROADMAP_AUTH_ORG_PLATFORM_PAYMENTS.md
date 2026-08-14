# Implementation Roadmap — Registration, Auth, Org, Platform, Payments

**Last updated:** 2026-08-14  
**Supabase:** `tappfahlaiixctyliesz`  
**Live proof:** multi-tenant orgs + team members + **org role catalog** (Team UI)

*Aligned with comparative progress report, multi-tenancy strategy, and verified live usage.*

---

## End product picture

| Pillar | User-facing outcome | Non-negotiables |
|--------|---------------------|-----------------|
| **Registration** | Confirm work email → apply org → Peeke approve | Email ownership proven before org create |
| **Auth** | Sign-in, recovery, invite set-password, session across restarts | No secrets in client; clear errors; later MFA for owners |
| **Org** | Tenant boundary, roles, depts, invites, org switch | RLS on every domain table; elevated approvals when multi-user |
| **Platform** | Peeke Automation admins manage tenants & plans | `is_platform_admin()` only; audited support access later |
| **Payments** | Paystack BYO + platform billing | **Secrets never reach Flutter**; webhooks service-role only |

**Design:** Landing + launcher stay strict 3-color logo system (sky `#D3EFFD`, navy `#272A6D`, teal `#55AAAC`). Post-login may add *status* hues without changing that base.

**Two entry paths (locked):**

| Path | Who | Flow |
|------|-----|------|
| **Tenant** | Org owner | Register → confirm email → Apply organisation → approval |
| **Team member** | Invitee | Accept invitation → `/accept-invite` (name + phone + password) → member |

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
| P0.1 | Remove payment secret exposure | ✅ | Column REVOKE + `set_organization_payment_secrets` RPC |
| P0.2 | Isolation test script | 🟨 | Re-run formally with Tentons member vs Peeke Systems |
| P0.3 | Friendly errors app-wide | 🟨 | Auth/registration improved |

---

## P1 — Trust & onboarding

| # | Item | Status | Notes |
|---|------|--------|-------|
| P1.1 | Auth / registration gate polish | ✅ | Branded login, hard gate apply, 3-color theme |
| P1.2 | Org invites + membership management | ✅ | Invite, revoke, remove, accept-invite |
| P1.3 | Org roles + personal details | 🟨 | Catalog CEO…Operator; depts seeded; Team invite/edit; **work-loop gates still open** |
| P1.4 | Elevate WO/WR approval by role | ⬜ | `requireElevatedForApproval` still false |

See [ORG_ROLES_AND_DEPARTMENTS.md](ORG_ROLES_AND_DEPARTMENTS.md).

---

## P2 — Platform & billing product

| # | Item | Status | Notes |
|---|------|--------|-------|
| P2.1 | Plan enforcement | 🟨 | Assign UI exists; no hard gate when past_due |
| P2.2 | Charge + webhook Edge Functions | 🟨 | Secrets RPC path; no production charge FN |
| P2.3 | Tenant offboarding | ⬜ | |
| P2.4 | Platform admin UX | 🟨 | |
| P2.5 | Marketing site (Option A) | ⬜ | Static Cloudflare Pages → app CTAs |

---

## P3 — Domain depth

| # | Item | Status |
|---|------|--------|
| P3.1 | Clients/systems parity | 🟨 |
| P3.2 | Work module depth | 🟨 |
| P3.3 | Maintenance surgical import | 🟨 |
| P3.4 | Offline (PowerSync) | ⬜ |

---

## Recommended sequence from here

1. Department picker UI on Team + HoD multi-dept  
2. Wire one work loop to Supervisor/HoD (P1.4 / P3.2)  
3. Formal isolation test (P0.2)  
4. fault_codes + maintenance depth  
5. Plan gate + production email  
6. Marketing site Option A when capacity allows  
7. Offline engine for field trials  

---

## Related docs

- [ROADMAP.md](ROADMAP.md)  
- [ORG_ROLES_AND_DEPARTMENTS.md](ORG_ROLES_AND_DEPARTMENTS.md)  
- [INVITE_MEMBER_FLOW.md](INVITE_MEMBER_FLOW.md)  
