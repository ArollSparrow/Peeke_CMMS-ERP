# CI Android APK → Cloudflare R2

**Status:** Wired in `.github/workflows/build-android-apk.yml` + short download Worker  
**Goal:** Downloadable debug APKs without GitHub Actions artifact quota.

## Short download link (use this)

**https://peeke-apk.peeke.workers.dev/**

- Always points at the latest `ci/apk/peeke-cmms-erp-debug.apk` in bucket `peeke-ci`.
- Worker issues a fresh 1-hour R2 presigned URL and **302 redirects** (APK is ~150 MB; avoids Worker response size limits).
- Bookmark this URL; no need to copy long presign strings from Actions.

Health check: `https://peeke-apk.peeke.workers.dev/health`

## Behaviour

| Trigger | Build | Publish to R2 | GitHub artifact |
|---------|-------|---------------|-----------------|
| Push to `main` | Yes | No | No |
| Manual *Run workflow* (defaults) | Yes | **Yes** | No |

R2 keys:

- `ci/apk/peeke-cmms-erp-debug.apk` — latest (what the short link serves)
- `ci/apk/peeke-cmms-erp-debug-<run_id>.apk` — immutable per run

## Required GitHub secrets

| Secret | Purpose |
|--------|--------|
| `CLOUDFLARE_ACCOUNT_ID` | R2 S3 endpoint |
| `R2_ACCESS_KEY_ID` | R2 S3 API |
| `R2_SECRET_ACCESS_KEY` | R2 S3 API |
| `R2_BUCKET` | `peeke-ci` |

Worker `peeke-apk` uses the same R2 S3 credentials as secrets on the Worker.

## Related

- [ADR 004 — Hybrid storage](adr/004-hybrid-storage-r2-supabase.md)
- [EDGE_AND_STORAGE_OPTIMIZATIONS.md](EDGE_AND_STORAGE_OPTIMIZATIONS.md)
