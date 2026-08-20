# PowerSync Cloud bootstrap (Peeke)

**Working branch (until PowerSync is done):** `infra/powersync-cloud-bootstrap`

Do not merge to redesign until streams + publication + one domain cutover are proven.
All PowerSync commits and preview deploys stay on this branch.

## Policy: every push gets a dry run

Push runs **Dry run (analyze)** then **Cloudflare Pages** deploy
(see `.github/workflows/deploy-cloudflare-pages.yml`).

## What is on the branch

| Artifact | Purpose |
|----------|---------|
| `powersync/sync-streams.yaml` | Org-membership-scoped streams (clients/systems v1) |
| `lib/infra/sync/peeke_schema.dart` | Local SQLite schema with `organization_id` (clients + systems expanded) |
| `lib/infra/sync/supabase_connector.dart` | JWT credentials + RLS upload |
| `lib/infra/sync/powersync_database.dart` | Open/connect/clear lifecycle |
| `lib/infra/sync/sync_providers.dart` | Riverpod hooks + local clients/systems watch |
| `lib/features/org/home_shell_screen.dart` | Connect on session; clear on logout; sync icon when configured |
| `lib/features/clients/client_providers.dart` | Dual-read clients + systems (local SQLite when configured) |
| `supabase/migrations/20260820_powersync_publication.sql` | Publication allowlist stub |
| `docs/adr/004-powersync-cloud-saas-offline.md` | Decision record |

Without `POWERSYNC_URL`, the app behaves as online-only Supabase (icon hidden).

## Your next ops steps (cannot be done from the app alone)

1. **PowerSync Cloud** — create project/instance (Team if SOC 2 report needed).
2. **Connect Supabase** `tappfahlaiixctyliesz` with a replication role.
3. **Publication allowlist** — apply the SQL in `20260820_powersync_publication.sql` (edit role/password; do not use `FOR ALL TABLES`).
4. **Deploy streams** — paste `powersync/sync-streams.yaml` → Validate → Deploy.
5. **Two-tenant test** — user B must not download org A clients/systems.
6. **Local/preview with sync:**
   ```bash
   flutter run --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com
   ```
   Or add the same define to the Cloudflare workflow later for preview builds.

## After ops are green

Next engineering bite on **this same branch**:

- UI can already dual-read clients + systems via the list/by-id providers.
- Optionally switch list screens to the pure `local*WatchProvider` streams once data is confirmed flowing.
- Then uncomment work_orders / work_requests streams + schema.

## Preview URL

https://infra-powersync-cloud-bootstrap.peeke-cmms-erp.pages.dev

Actions: https://github.com/ArollSparrow/Peekes/actions
