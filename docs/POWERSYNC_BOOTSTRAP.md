# PowerSync Cloud bootstrap (Peeke)

**Working branch (until PowerSync is done):** `infra/powersync-cloud-bootstrap`

Do not merge to redesign until streams + publication + one domain cutover are proven.
All PowerSync commits and preview deploys stay on this branch.

This branch is **infrastructure foundation** — dual-read paths exist so offline can light up when ops are green. Production feature polish is out of scope here.

## Policy: every push gets a dry run

Push runs **Dry run (analyze)** then **Cloudflare Pages** deploy
(see `.github/workflows/deploy-cloudflare-pages.yml`).

## What is on the branch

| Artifact | Purpose |
|----------|---------|
| `powersync/sync-streams.yaml` | Org-membership streams: orgs, clients, systems, work_orders, work_requests |
| `lib/infra/sync/peeke_schema.dart` | Local SQLite schema (`organization_id` on every synced table) |
| `lib/infra/sync/supabase_connector.dart` | JWT credentials + RLS upload |
| `lib/infra/sync/powersync_database.dart` | Open/connect/clear lifecycle |
| `lib/infra/sync/sync_providers.dart` | Status stream, hasSynced, local watches |
| `lib/features/org/home_shell_screen.dart` | Connect on session; clear on logout; live sync icon |
| `lib/features/clients/client_providers.dart` | Reactive dual-read clients + systems |
| `lib/features/work/work_providers.dart` | Reactive dual-read work orders + requests + KPI counts |
| `supabase/migrations/20260820_powersync_publication.sql` | Publication allowlist stub |
| `docs/adr/004-powersync-cloud-saas-offline.md` | Decision record |

Without `POWERSYNC_URL`, the app behaves as online-only Supabase (icon hidden).

## Your next ops steps (cannot be done from the app alone)

1. **PowerSync Cloud** — create project/instance (Team if SOC 2 report needed).
2. **Connect Supabase** `tappfahlaiixctyliesz` with a replication role.
3. **Publication allowlist** — apply the SQL in `20260820_powersync_publication.sql` (edit role/password; do not use `FOR ALL TABLES`).
4. **Deploy streams** — paste `powersync/sync-streams.yaml` → Validate → Deploy.
5. **Two-tenant test** — user B must not download org A rows.
6. **Local/preview with sync:**
   ```bash
   flutter run --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com
   ```

## Foundation coverage (code)

| Domain | Streams | Schema | Dual-read lists | Notes |
|--------|---------|--------|-----------------|-------|
| Membership / orgs | yes | yes | (auth path) | auto_subscribe |
| Clients | yes | yes | reactive watch | |
| Systems | yes | yes | reactive watch | |
| Work requests | yes | yes | reactive watch | status filter client-side offline |
| Work orders | yes | yes | reactive watch | open-count KPI local |
| WO parts / events | stub only | no | network only | next infra bite |

Writes always go through Supabase JWT + Postgres RLS.

## Preview URL

https://infra-powersync-cloud-bootstrap.peeke-cmms-erp.pages.dev

Actions: https://github.com/ArollSparrow/Peekes/actions
