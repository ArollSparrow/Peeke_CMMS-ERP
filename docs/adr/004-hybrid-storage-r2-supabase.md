# ADR 004 — Hybrid storage: Supabase Storage + Cloudflare R2

**Status:** Accepted  
**Date:** 2026-08-16  
**Context:** Clean-slate Peeke CMMS-ERP (`Peeke_CMMS-ERP`)

## Decision

Use a **hybrid storage architecture** that plays to each service’s strengths:

- **Supabase Storage** → private / strongly authenticated / RLS-bound files only.
- **Cloudflare R2** → default home for binary blobs (especially media, large files, and anything with meaningful download volume).
- **Supabase Postgres** → single source of truth for metadata, ownership, and visibility.

Never put S3/R2 credentials in the Flutter client. All privileged access goes through short-lived presigned URLs issued by Cloudflare Workers (or Supabase Edge Functions).

## Why

| Concern | Supabase Storage alone | R2 alone | Hybrid (chosen) |
|---------|------------------------|----------|-----------------|
| Free storage | ~1 GB | 10 GB | Stretch both |
| Egress | Limited (can bill) | **Free** | Protects bandwidth |
| RLS / JWT native | Excellent | None (must build) | Best of both |
| Large files / media | 50 MB free limit | Comfortable | R2 wins |
| Mobile + Workers already | — | Already wired for presign | Low extra cost |

Peeke is multi-tenant CMMS/ERP. Typical attachments (work-order photos, equipment images, invoices, manuals) are org-scoped and private. High download volume or large files would burn Supabase free egress and storage quickly. R2 gives free egress and headroom while we keep auth and metadata in Supabase.

## Architecture (target)

```
Flutter / Web client
  → requests upload or download URL from our API (Worker or Edge Function)
  → API validates Supabase JWT + organization membership (RLS / claims)
  → API returns short-lived presigned R2 URL (or Supabase signed URL for rare private cases)
  → client talks directly to R2 or Supabase Storage for the bytes

Postgres tables (e.g. attachments, work_order_media)
  → organization_id, owner_id, key/path, storage_backend ('r2' | 'supabase'),
     content_type, size, visibility, created_at, …
  → RLS enforces tenant isolation on metadata
```

### Routing rule of thumb

| File type / pattern | Store in | Reason |
|---------------------|----------|--------|
| Work-order photos, asset images, large media | **R2** | Volume + free egress |
| Sensitive docs that must never be accessible via a leaked URL without fresh auth | **Supabase Storage** (or R2 + Worker gate) | Native RLS / JWT |
| Branding, static public assets | R2 (or Cloudflare Pages) | CDN + free egress |
| Metadata / search / lists | Postgres only | Query + RLS |

Default for **new** uploads: **R2**. Use Supabase Storage only when the stronger native RLS model is clearly required.

## Security rules

1. **No long-lived R2 or S3 keys in the client** (Flutter, web, or logs).
2. Presigned URLs are short-lived (minutes, not hours/days).
3. Worker / Edge Function always validates the caller’s Supabase JWT and `organization_id` before issuing a URL.
4. Object keys are namespaced by `organization_id` (and preferably by entity) so a leaked key cannot easily traverse tenants.
5. Metadata rows are the authority for “does this user/org own this file?” — never rely on URL secrecy alone for authorization decisions in the app.
6. Prefer `overwrite: false` / unique keys; soft-delete metadata before hard-deleting objects.

## Non-goals (for now)

- Full background migration of every historical file (we have little history yet).
- Cloudflare Worker as a permanent reverse-proxy auth layer for every private object (presigned URLs are sufficient and simpler).
- Pointing hosted Supabase Storage backend at R2 (self-host only pattern).

## Migration / evolution path

1. **Now:** Document decision; keep existing R2 + Workers presign path; route new attachment flows to R2 by default.
2. **Next:** Standardize an `attachments` (or equivalent) table with `storage_backend` + key/URL columns.
3. **Later (if needed):** Background job to move any residual Supabase Storage objects to R2 and update metadata.
4. **Only if required:** Add Worker-side JWT gate for private R2 objects that cannot use short-lived presigned URLs.

## Implications for product

- Upload UX stays simple: client asks backend for a URL, then PUTs the file.
- Download UX: client receives a short-lived URL (or streams via Worker in edge cases).
- Free-tier headroom stays healthy longer; egress surprises are avoided.
- Auth story remains consistent with the rest of the platform (Supabase JWT + org RLS).

## Related

- Foundation: Cloudflare Pages + Workers preferred for edge.
- Secrets: server-only (same rule as Paystack secrets in ADR 001).
- Multi-tenancy: every attachment metadata row is `organization_id`-scoped + RLS.
