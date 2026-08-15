# ADR 005 — Zero Trust scope & R2 Worker hardening

**Status:** Accepted  
**Date:** 2026-08-16  
**Context:** Clean-slate Peeke CMMS-ERP (`Peeke_CMMS-ERP`)  
**Related:** [ADR 004 — Hybrid storage](004-hybrid-storage-r2-supabase.md)

## Decision

Apply a **narrow, high-ROI Zero Trust posture** around object storage and privileged edge endpoints. Do **not** put Cloudflare Access in front of the normal app or the R2 presign path used by mobile/web clients.

### What we implement (worth the salt)

1. **R2 buckets remain private** — no public access, no long-lived client credentials.
2. **Cloudflare Workers are the only privileged door** to R2. They hold the R2 API credentials as secrets.
3. **Presigned URLs only**, short-lived, issued after the Worker validates a Supabase JWT and organization membership.
4. **Object key namespace** by `organization_id` (and preferably entity) so a leaked key cannot easily traverse tenants.
5. **Cloudflare Access only on true admin / platform-owner surfaces** (tenant approval console, internal tools, staging if needed). Never on the main CMMS app or normal upload/download flow.
6. **Rate limiting** on the presign endpoint (IP + user) to blunt abuse.

### What we explicitly skip for now (not worth the salt)

- Cloudflare Access in front of every R2 object or the Flutter app.
- Full Zero Trust Gateway / WARP for end users.
- mTLS between all services.
- Worker-as-permanent-reverse-proxy for every private object (presigned URLs are simpler and sufficient).
- Pointing hosted Supabase Storage at R2.

## Architecture (target)

```
Client (Flutter / Web)
  → Authorization: Bearer <supabase_jwt>
  → POST /presign  { action, key, contentType, … }

Cloudflare Worker
  1. Verify Supabase JWT (signature + expiry)
  2. Resolve organization membership / claims
  3. Enforce key prefix: must start with org/{organization_id}/
  4. Issue short-lived R2 presigned URL (upload or download)
  5. Optional: rate-limit by IP + sub

Client
  → PUT/GET directly to the presigned R2 URL (bytes never proxy through Worker)

Postgres (attachments / media tables)
  → organization_id, storage_backend, object_key, … + RLS
```

## Concrete Worker rules (implementation checklist)

| Rule | Detail |
|------|--------|
| Auth required | Reject requests without a valid Supabase JWT |
| Org binding | Caller must be a member of the target `organization_id` |
| Key prefix | Object key **must** begin with `org/{organization_id}/` |
| TTL | Upload: ~5–15 min; Download: as short as practical for the use case |
| No raw credentials | R2 access keys exist only as Worker secrets |
| Rate limit | Soft limit per IP and per user on the presign route |
| Logging | Log `sub`, `organization_id`, action, key prefix — never the full presigned URL or secrets |

## Cloudflare Access usage (narrow)

| Surface | Access? | Why |
|---------|---------|-----|
| Main CMMS app (Pages + Flutter) | **No** | Supabase Auth is the identity layer; Access would add friction for field users |
| R2 presign Worker (normal path) | **No** | JWT + org checks inside Worker are enough |
| Platform admin / tenant-approval console | **Yes** | Small audience, high sensitivity |
| Internal debug / staging admin routes | **Yes** (optional) | Keep out of public internet |
| Future machine-to-machine | Service token if needed | Prefer short-lived or rotated secrets |

## Security invariants

1. Secrets never ship in the Flutter client or web bundle.
2. Authorization decisions for files live in Postgres + RLS and in the Worker checks — URL secrecy is a secondary control only.
3. Soft-delete metadata first; hard-delete R2 objects later (or via lifecycle).
4. Prefer unique object keys; avoid overwrite-by-default for user content.

## Evolution

- **Now:** Codify the rules above; harden the existing presign Worker to match the checklist.
- **Next:** Standardize attachment metadata table (`storage_backend`, `object_key`, …) per ADR 004.
- **Later only if needed:** Worker JWT gate for objects that cannot use presigned URLs, or Access on additional admin surfaces.

## Related

- [ADR 004 — Hybrid storage (Supabase + R2)](004-hybrid-storage-r2-supabase.md)
- [ADR 001 — BYO payments](001-tenant-payments-byo.md) (same “secrets server-only” principle)
- Foundation: Cloudflare Pages + Workers preferred for edge.
