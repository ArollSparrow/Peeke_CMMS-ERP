# CI Android APK → Cloudflare R2

**Status:** Wired in `.github/workflows/build-android-apk.yml`  
**Goal:** Downloadable debug APKs without using GitHub Actions artifact storage quota.

## Behaviour

| Trigger | Build | Publish to R2 | GitHub artifact |
|---------|-------|---------------|-----------------|
| Push to `main` (lib/android/…) | Yes | No | No |
| Manual *Run workflow* (defaults) | Yes | **Yes** | No |
| Manual + “Also upload to GitHub…” | Yes | Yes | Optional |

R2 object keys:

- `ci/apk/peeke-cmms-erp-debug.apk` — latest stable pointer (overwritten each publish)
- `ci/apk/peeke-cmms-erp-debug-<run_id>.apk` — immutable copy per run

Job summary prints a **presigned GET URL** (expires in **1 hour**).

## Required GitHub secrets

Repo → **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|--------|--------|
| `CLOUDFLARE_ACCOUNT_ID` | Already used by Pages deploy; R2 S3 endpoint host |
| `R2_ACCESS_KEY_ID` | R2 API token Access Key ID |
| `R2_SECRET_ACCESS_KEY` | R2 API token Secret Access Key |
| `R2_BUCKET` | Bucket name (e.g. `peeke-ci` or an existing private bucket) |

### Create R2 API token (Cloudflare dashboard)

1. **R2** → **Manage R2 API Tokens** → **Create API token**.
2. Permissions: **Object Read & Write** on the chosen bucket (or account).
3. Copy Access Key ID + Secret Access Key into the GitHub secrets above.
4. Create a bucket if needed (e.g. `peeke-ci`). Keep it **private**; CI uses presigned URLs.

Optional later: R2 lifecycle rule on `ci/apk/` to expire dated objects after 7–14 days (keep the stable key or overwrite only).

## How to get an APK

1. Actions → **Build Android APK** → **Run workflow**.
2. Leave **Publish APK to Cloudflare R2** checked (default).
3. When the job finishes, open the run → **Summary** → copy the presigned link (valid ~1 hour).
4. Or re-presign yourself with AWS CLI / a Worker if the link expired.

## Related

- [ADR 004 — Hybrid storage](adr/004-hybrid-storage-r2-supabase.md)
- [EDGE_AND_STORAGE_OPTIMIZATIONS.md](EDGE_AND_STORAGE_OPTIMIZATIONS.md)
