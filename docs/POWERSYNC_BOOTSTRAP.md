# PowerSync Cloud bootstrap (Peeke)

Branch: `infra/powersync-cloud-bootstrap`

## What this bite includes

| Artifact | Purpose |
|----------|---------|
| `powersync/sync-streams.yaml` | Org-membership-scoped streams (clients/systems v1) |
| `lib/infra/sync/peeke_schema.dart` | Local SQLite schema with `organization_id` |
| `lib/infra/sync/supabase_connector.dart` | JWT credentials + RLS upload |
| `lib/infra/sync/powersync_database.dart` | Open/connect/clear lifecycle |
| `lib/infra/sync/sync_providers.dart` | Riverpod hooks + sample clients watch |
| `supabase/migrations/20260820_powersync_publication.sql` | Publication allowlist stub |
| `docs/adr/004-powersync-cloud-saas-offline.md` | Decision record |

UI is **not** cut over yet. App runs as today until `POWERSYNC_URL` is set and
providers are watched from a screen.

## Prerequisites

1. Run `scripts/isolation_rls_checklist.sql` — RLS on for clients/systems.
2. Create PowerSync Cloud project; connect Supabase; create replication role.
3. Apply publication allowlist (edit SQL stub, then run on project).
4. Deploy `powersync/sync-streams.yaml` in the Dashboard (Validate → Deploy).
5. Confirm two-tenant test: user B never downloads org A clients.

## Run with sync enabled

```bash
git checkout infra/powersync-cloud-bootstrap
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://tappfahlaiixctyliesz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com
```

Then from a widget/provider scope:

```dart
ref.watch(powerSyncConnectionProvider);
final clients = ref.watch(localClientsWatchProvider);
```

## Logout

Call `PeekePowerSync.disconnectAndClear()` when signing out so the next user on
the device does not see prior tenant rows.

## Next bites

1. Live publication + stream deploy on staging instance.
2. Hook `powerSyncConnectionProvider` after auth in shell.
3. Cut clients list to `localClientsWatchProvider`.
4. Uncomment work_orders streams + schema when ready.
