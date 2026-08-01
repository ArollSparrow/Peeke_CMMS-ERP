# ADR 001 — Tenant bring-your-own (BYO) payment accounts

**Status:** Accepted  
**Date:** 2026-08-01  
**Context:** Clean-slate Peeke CMMS-ERP (`Peeke_CMMS-ERP`)

## Decision

Peeke is a **platform**. Each **tenant (organization)** connects and uses **their own** payment provider account (starting with **Paystack**).  
Peeke does **not** collect client/customer money into a central Peeke merchant account and split it.

Money for a tenant’s invoices, WO fees, contracts, etc. settles to **that tenant’s** Paystack (or later Stripe) account.

Optional later: Peeke’s **own** Paystack account only for **SaaS platform fees** (subscription to use Peeke), separate from tenant operational payments.

## Why

- Tenants keep full control of settlement, payouts, disputes, and tax identity.
- Avoids Peeke becoming the merchant-of-record for every facility’s clients.
- Matches multi-tenant CMMS/ERP where each org is an independent business.
- Simpler compliance posture for the platform vs marketplace money movement.

## Non-goals (for now)

- Paystack **subaccounts / transaction splits** under one Peeke merchant (marketplace model).
- Peeke holding client funds or acting as payment intermediary for tenant customers.

## Architecture

```
Tenant org admin
  → enters Paystack public key + secret key (or OAuth later)
  → stored encrypted, org-scoped, server-only

Flutter app
  → uses tenant public key for checkout UI only

Edge (Supabase Edge Function / Cloudflare Worker)
  → loads tenant secret key server-side
  → initialize charge / verify webhook with that tenant’s secret
  → writes payment_events scoped by organization_id

Paystack
  → settles to the TENANT’s bank account
```

### Data (sketch)

| Table / concept | Purpose |
|-----------------|--------|
| `organizations` | Tenant root |
| `org_payment_credentials` | provider, public_key, secret_key_encrypted, webhook_secret, is_live, status |
| `payment_events` | org_id, provider, reference, amount, status, raw payload (audit) |
| `invoices` / domain docs | Link to payment reference; status updated from webhooks |

### Security rules

1. **Secret keys never leave the server** (no Flutter, no client logs).
2. Secrets stored **encrypted at rest** (Supabase Vault / pgcrypto / KMS pattern).
3. RLS: only org admins manage credentials for their `organization_id`.
4. Webhooks: verify signature with **that org’s** secret; reject if org unknown.
5. Prefer unique webhook URL per org (`/webhooks/paystack/{org_id}`) or signed routing metadata.

### Provider sequence

1. **Paystack** (Kenya-first local methods) — BYO per tenant.
2. **Stripe** (optional, same BYO pattern) for tenants who need global cards.
3. **Manual / bank transfer** — status only, no gateway keys.

## Implications for product

- Onboarding includes a **Payments** step: “Connect your Paystack account”.
- Tenants without credentials can still use the CMMS; payment collection features stay disabled until connected.
- Platform subscription (if any) is a **separate** product surface using Peeke’s merchant account — not mixed with tenant checkout.

## Related

- Multi-tenancy: every payment row and credential row is `organization_id`-scoped.
- Activepieces / Slack: react to `payment_events` domain status, not to raw provider SDKs in the app.
