# ADR 002 — Platform owner vs tenant accounts

## Context

Peeke is a multi-tenant SaaS. Two money flows exist:

1. **Tenant → Platform** — organization pays Peeke a subscription to use the product.
2. **Customer → Tenant** — organization collects from *their* clients using BYO Paystack (ADR 001).

These must not share merchant accounts.

## Decision

| Role | Who | Login lands on | Payment keys |
|------|-----|----------------|--------------|
| **Platform owner** | Peeke operator (`platform_admins`) | `/platform` | `platform_payment_settings` (Peeke Paystack) |
| **Tenant member** | User in `organization_members` | `/home` (CMMS) | `organization_payment_settings` (tenant BYO) |

A user can be both (e.g. Peeke Automation as a demo tenant *and* platform admin). Platform admin still defaults to `/platform`, with a link to open the tenant CMMS.

## Schema

- `platform_admins(user_id)`
- `platform_payment_settings` — single merchant for SaaS billing
- `subscription_plans` — Starter / Growth / Enterprise
- `organization_subscriptions` — status, plan, period per tenant
- Existing `organization_payment_settings` unchanged for BYO

## Routing

Post-login gate (`/gate`) calls `is_platform_admin()` → `/platform` or `/home`.
