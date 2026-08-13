# ADR 003 — Organisation approval (hard gate + testing window)

**Status:** Accepted  
**Date:** 2026-08-13  
**Phrase:** *Clarity without clutter.*

## Decision

Peeke Automation uses the **hardest production gate** with a **restrained testing window**:

| Status | Product (CMMS) access |
|--------|------------------------|
| `pending` | No — wait for review |
| `testing` | Yes, until `testing_until` |
| `active` | Yes |
| `rejected` | No |
| `suspended` | No |

- New organisations are created as **`pending`** (not active).
- Existing live tenants remain **`active`**.
- Platform admins may:
  - **Approve** → `active`
  - **Test window** → `testing` + `testing_until` (default 14 days)
  - **Reject** / **Suspend**

## Rationale

- Control who reaches the product without soft-open spam.
- Keep an elegant path for real trials: time-boxed `testing`, not permanent silent access.
- UI stays calm: one status screen, no noise.

## Consequences

- Create organisation → pending screen, not `/home`.
- Team invites should only run for orgs with product access (enforced progressively).
- Platform Tenants console is the review surface.
