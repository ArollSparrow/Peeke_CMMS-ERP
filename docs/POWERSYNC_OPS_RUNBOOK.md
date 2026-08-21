# PowerSync ops runbook (Peeke)

**Branch:** `infra/powersync-cloud-bootstrap`  
**Supabase project:** `tappfahlaiixctyliesz` (Peeke CMMS-ERP, eu-central-1)

## Status (2026-08-21)

| Step | Status |
|------|--------|
| 1. PowerSync Cloud instance | **You** — dashboard only |
| 2. Publication allowlist | **Done** on Supabase (6 tables) |
| 3. Deploy `powersync/sync-streams.yaml` | **You** — paste in dashboard |
| 4. Two-tenant isolation test | Checklist in `scripts/powersync_two_tenant_isolation.sql` |

Replication role: `powersync_role` (REPLICATION + BYPASSRLS + LOGIN).  
Password is **not** in git — use the value from the session that created the role (or reset via SQL).

## 1) Create PowerSync Cloud instance

1. Sign up / log in: https://dashboard.powersync.com/
2. Create a project (e.g. **Peeke**). Default Dev + Prod instances appear.
3. Prefer region **EU** to match Supabase `eu-central-1` when offered.
4. Open the instance → **Database Connections** → Connect Postgres.
5. Use **Direct** host (not pooler):
   - Host: `db.tappfahlaiixctyliesz.supabase.co`
   - Port: `5432`
   - Database: `postgres`
   - User: `powersync_role`
   - Password: *(ops vault)*
   - Or URI:  
     `postgresql://powersync_role:PASSWORD@db.tappfahlaiixctyliesz.supabase.co:5432/postgres`
6. **Client Auth** → enable **Use Supabase Auth**  
   - New JWT signing keys: leave legacy secret empty.  
   - Legacy HS256: paste JWT secret from Supabase → Project Settings → JWT.
7. Save / Deploy connection.

## 2) Publication (already applied)

Allowlist only (not `FOR ALL TABLES`):

- `organization_members`
- `organizations`
- `clients`
- `systems`
- `work_orders`
- `work_requests`

Verify:

```sql
SELECT tablename FROM pg_publication_tables WHERE pubname = 'powersync' ORDER BY 1;
```

## 3) Deploy Sync Streams

1. PowerSync Dashboard → instance → **Sync Streams** (edition 3).
2. Paste contents of repo file `powersync/sync-streams.yaml`.
3. **Validate** against the connected database.
4. **Deploy**.

Streams are membership-scoped via `organization_members` + `auth.user_id()`.

## 4) Two-tenant isolation

1. Run `scripts/powersync_two_tenant_isolation.sql` for baseline counts.
2. With app:
   ```bash
   flutter run --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com
   ```
3. User B must not download Org A clients/systems/work rows.
4. Logout clears local DB (`disconnectAndClear`).

## App wiring (already on branch)

- Opt-in: `POWERSYNC_URL` only.
- Without it: online-only Supabase.
- Dual-read lists for clients, systems, work orders/requests.

## Do not

- Commit `powersync_role` password.
- Use `FOR ALL TABLES` publication in production.
- Sync `organization_payment_settings` secrets.
