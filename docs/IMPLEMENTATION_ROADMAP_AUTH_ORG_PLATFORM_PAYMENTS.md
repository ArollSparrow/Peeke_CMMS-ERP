# Implementation Roadmap — Registration, Auth, Org, Platform, Payments

*Aligned with comparative progress report (2026-08-09), multi-tenancy strategy, and live checks on `tappfahlaiixctyliesz`.*

## End product picture

| Pillar | User-facing outcome | Non-negotiables |
|--------|---------------------|-----------------|
| **Registration** | Confirm work email → create tenant → register clients/systems | Email ownership proven before org create |
| **Auth** | Sign-in, recovery, session across restarts | No secrets in client; clear errors; later MFA for owners |
| **Org** | Tenant boundary, roles, invites, org switch | RLS on every domain table; elevated approvals when multi-user |
| **Platform** | Peeke Automation admins manage tenants & plans | `is_platform_admin()` only; audited support access later |
| **Payments** | Paystack BYO + platform billing | **Secrets never reach Flutter**; webhooks service-role only |

**Design:** Landing + launcher stay strict 3-color logo system (sky `#D3EFFD`, navy `#272A6D`, teal `#55AAAC`). Post-login may add *status* hues without changing that base.

---

## Live security findings (verified)

1. **`organization_payment_settings` SELECT** allows *any* org member (`organization_id IN my_organization_ids()`), including columns `secret_key` and `webhook_secret`.
2. **Flutter** `PaymentRepository.getSettings` uses `.select()` → full row, including secrets.
3. **`payment_transactions` UPDATE** is any org member — should be admin/webhook only.
4. Platform payment settings are admin-gated (better), but secrets still should not round-trip to the browser even for platform admins if avoidable.

These match the multi-tenancy strategy note: fix payment credentials first.

---

## Sequencing (do in order)

### P0 — Security foundation (blockers)

| # | Item | Why |
|---|------|-----|
| P0.1 | **Remove payment secret exposure** | Any member can read Paystack secret today |
| P0.2 | **Isolation test script** | Prove RLS on all `organization_id` tables |
| P0.3 | **Friendly errors app-wide** | ~41 spots still show raw exceptions (registration fixed) |

### P1 — Trust & onboarding

| # | Item |
|---|------|
| P1.1 | Auth/Registration gate polish (branded create-org, confirm-email UX) |
| P1.2 | Org invites + membership management |
| P1.3 | Optional: elevate WO/WR approval (`requireElevatedForApproval`) |

### P2 — Platform & billing product

| # | Item |
|---|------|
| P2.1 | Decide plan enforcement (`trialing` / `past_due` → app gate and/or RLS) |
| P2.2 | Edge Functions: charge + webhook verify (service role only) |
| P2.3 | Tenant offboarding shape (soft delete + retention) |
| P2.4 | Platform admin UX (branded, no secret display) |

### P3 — Domain depth (from comparative report)

| # | Item |
|---|------|
| P3.1 | Resolve clients `contact` vs split fields; systems `type` vs `system_type` |
| P3.2 | Work module depth toward production parity |
| P3.3 | Maintenance surgical import from Peeke™ |
| P3.4 | Offline mobile (PowerSync) per Phase 1 roadmap |

---

## P0.1 design — payment secrets

**Principle:** client may see `public_key`, flags, and labels only.

1. **DB**
   - Column privileges or view without `secret_key` / `webhook_secret` for `authenticated`.
   - `service_role` retains full access for Edge Functions.
   - `SECURITY DEFINER` RPC `set_organization_payment_secrets(...)` for org admins (write-only; never returns secrets).
   - Tighten `payment_transactions` UPDATE to `is_org_admin(organization_id)` (or no client UPDATE — webhook only).
2. **App**
   - Explicit `.select(...)` list excluding secrets.
   - Settings UI: password fields write via RPC; UI shows “Set” / “Update” never the value.
3. **Later**
   - Edge Function proxy for Paystack API calls.

---

## Decisions to lock (design only, before heavy feature work)

- Plan enforcement: app-level first, RLS later if needed.
- Offboarding: soft-delete org + retention window.
- Platform support: logged “view as” preferred over session assumption.
- Vendors remain org-scoped (confirmed intent).

---

## Current pick — start immediately

**P0.1 Remove payment secret exposure** (DB + Flutter).

Next after that: isolation test script (P0.2), then Auth/create-org polish (P1.1).
