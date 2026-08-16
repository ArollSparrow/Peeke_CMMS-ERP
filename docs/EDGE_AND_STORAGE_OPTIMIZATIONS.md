# Edge & storage optimizations — worth the salt

**Date:** 2026-08-16  
**Scope:** Cloudflare + Supabase choices that compound with [ADR 004](adr/004-hybrid-storage-r2-supabase.md) and [ADR 005](adr/005-zero-trust-r2-worker-hardening.md).  
**Rule:** Only items with clear free-tier or operational ROI; no cool-factor work.

## GitHub Actions APK (quota-safe)

Free-plan **artifact storage is account-wide** (~500 MB shared). Debug APKs are ~50–80 MB; repeated uploads exhaust the meter quickly, and deletes can lag 6–12h before new uploads work.

**Current policy (`.github/workflows/build-android-apk.yml`):**

| Trigger | Build APK | Upload to Actions artifacts |
|---------|-----------|-----------------------------|
| Push to `main` (lib/android/…) | Yes (verify compile) | **No** |
| Manual *Run workflow* | Yes | **No** unless “Upload APK…” is checked |

- Cleanup of old APK artifacts runs only when upload is explicitly requested.
- Upload uses `retention-days: 1`, `overwrite: true`, `continue-on-error: true`.
- Preferred long-term: publish APK to **R2** (presigned or short-lived public link) instead of Actions artifacts — same hybrid pattern as product media (ADR 004).

**Local APK when needed:**
```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://tappfahlaiixctyliesz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon>
# → build/app/outputs/flutter-apk/app-debug.apk
```

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

### 6. Optional: CI APK → R2 (unlock)
- After a successful manual (or tagged) Android build, Worker or workflow step uploads `app-debug.apk` to an R2 prefix e.g. `ci/apk/` with short lifecycle.
- Job summary prints a short-lived download URL.
- Bypasses GitHub artifact quota entirely; reuses the same R2 + presign muscle as product attachments.

## Explicit non-goals (for now)
- Full Cloudflare Gateway / WARP for end users
- Heavy image transformation pipelines
- Moving all binaries to one backend for purity
- Broad Realtime subscriptions where focus-refresh or polling is enough
- Migrating the whole repo to escape Actions storage (account-wide meter)

## Related
- [ADR 004 — Hybrid storage](adr/004-hybrid-storage-r2-supabase.md)
- [ADR 005 — Zero Trust & R2 Worker hardening](adr/005-zero-trust-r2-worker-hardening.md)
- [FOUNDATION.md](FOUNDATION.md) — Cloudflare Pages + Workers preferred for edge
