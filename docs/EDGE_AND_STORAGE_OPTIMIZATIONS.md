# Edge & storage optimizations — worth the salt

**Date:** 2026-08-16  
**Scope:** Cloudflare + Supabase choices that compound with [ADR 004](adr/004-hybrid-storage-r2-supabase.md) and [ADR 005](adr/005-zero-trust-r2-worker-hardening.md).  
**Rule:** Only items with clear free-tier or operational ROI; no cool-factor work.

## Ranked backlog (implement when touching the area)

### 1. R2 lifecycle rules + temp prefixes
- Incomplete / multipart uploads: delete after 1–3 days.
- Optional `temp/` or `staging/` prefix with short lifecycle (e.g. 7 days).
- Permanent objects under `org/{organization_id}/…` with long or no auto-delete.
- Soft-delete metadata in Postgres first; lifecycle or a periodic job removes bytes.

### 2. Single presign + metadata contract
- One Worker (or Edge) endpoint: validate Supabase JWT + org membership → write/update attachment row → return short-lived R2 presigned URL.
- Client never invents keys or talks to two backends for one upload.

### 3. Postgres: `organization_id` as first-class index citizen
- Every tenant list/filter query should hit a composite index that matches real patterns, e.g. `(organization_id, status, created_at DESC)`.
- Keep RLS simple so the planner can use those indexes.

### 4. Workers vs Supabase Edge Functions boundary
- **Workers:** presign, rate limits, lightweight webhooks, edge-fast paths.
- **Edge Functions:** multi-table transactions, rich RLS, service-role logic that is awkward from a Worker.
- Do not duplicate the same business rule in both places.

### 5. Soft size / egress guardrails (product-level)
- Soft per-org limits (max file size, total storage, optional download window) enforced at presign time and recorded in Postgres.
- Guardrails first; billing later.

## Explicit non-goals (for now)
- Full Cloudflare Gateway / WARP for end users
- Heavy image transformation pipelines
- Moving all binaries to one backend for purity
- Broad Realtime subscriptions where focus-refresh or polling is enough

## Related
- [ADR 004 — Hybrid storage](adr/004-hybrid-storage-r2-supabase.md)
- [ADR 005 — Zero Trust & R2 Worker hardening](adr/005-zero-trust-r2-worker-hardening.md)
- [FOUNDATION.md](FOUNDATION.md) — Cloudflare Pages + Workers preferred for edge
