# PowerSync ops runbook (Peeke)

**Branch:** `infra/powersync-cloud-bootstrap`  
**Supabase project:** `tappfahlaiixctyliesz` (Peeke CMMS-ERP, eu-central-1)

## Strategy: free account lasts ~1 week of inactivity

Do **not** create the PowerSync Cloud project until everything below is ready.
Then run **signup → connect → streams → Android/iOS test** in one sitting.

| Surface | PowerSync |
|---------|-----------|
| **Android / iOS** | Primary test target (local SQLite + sync) |
| **Web / Cloudflare preview** | Stays online-only unless you pass `POWERSYNC_URL` (not required for CI) |

Without `POWERSYNC_URL`, the app never opens a local PowerSync DB.

---

## Already done (no action)

| Item | Status |
|------|--------|
| Flutter schema + connector + lifecycle | On branch + production foundation |
| Dual-read providers (clients, systems, work) | Done |
| Home shell sync status + logout `disconnectAndClear` | Done |
| `powersync/sync-streams.yaml` (membership-scoped) | In repo |
| Publication allowlist on Supabase (6 tables) | **Live** |
| Role `powersync_role` (REPLICATION + BYPASSRLS + LOGIN) | **Live** |
| Two-tenant SQL checklist | `scripts/powersync_two_tenant_isolation.sql` |

---

## Last-mile sequence (when you are ready to use the free week)

### A) Sign up (once)

1. **Sign up** (not the dashboard Sign-in page):  
   https://accounts.powersync.com/portal/powersync-signup  
2. Then open: https://dashboard.powersync.com/ and sign in.  
3. **Create project** → name e.g. `Peeke`.  
   Accept default Dev (+ Prod) instances. Prefer **EU** region if offered.

### B) Connect Supabase (Development instance is enough for first test)

1. Instance → **Database Connections** → Postgres.  
2. **Direct** host (not pooler):

| Field | Value |
|--------|--------|
| Host | `db.tappfahlaiixctyliesz.supabase.co` |
| Port | `5432` |
| Database | `postgres` |
| User | `powersync_role` |
| Password | *(ops vault — created 2026-08-21; not in git)* |

URI shape:

```text
postgresql://powersync_role:PASSWORD@db.tappfahlaiixctyliesz.supabase.co:5432/postgres
```

3. **Test Connection** → Save / Deploy.  
4. **Client Auth** → enable **Use Supabase Auth**.  
   - New JWT keys: leave legacy secret empty.  
   - Legacy HS256 only: paste secret from Supabase → Project Settings → JWT.

### C) Deploy Sync Streams

1. Instance → **Sync Streams** (edition **3**).  
2. Paste the full contents of repo file:  
   `powersync/sync-streams.yaml`  
3. **Validate** → **Deploy**.

### D) Copy instance URL

From the dashboard (Connect / instance details), copy the endpoint, typically:

```text
https://<id>.powersync.journeyapps.com
```

### E) Native test only (Android or iOS)

```bash
# From repo root, on this branch:
flutter pub get

# Android example
flutter run -d android --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com

# iOS example
flutter run -d ios --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com
```

Checklist:

1. Sign in as **User A** (Org A only) → wait for sync icon → confirm clients/systems/work match Org A.  
2. Sign out (triggers `disconnectAndClear`).  
3. Sign in as **User B** (Org B only) → **no** Org A rows in local lists.  
4. Optional: airplane mode → lists still work from local SQLite; writes queue until online.  
5. SQL baseline: `scripts/powersync_two_tenant_isolation.sql`.

### F) After test

- Keep using the Free instance lightly so it is not idle for a full week, **or**  
- Upgrade later when production offline is required.  
- Do **not** put `POWERSYNC_URL` into Cloudflare Pages build until isolation is proven.

---

## Publication verify (already applied)

```sql
SELECT tablename FROM pg_publication_tables WHERE pubname = 'powersync' ORDER BY 1;
-- Expect: clients, organization_members, organizations, systems, work_orders, work_requests
```

## Do not

- Commit `powersync_role` password.  
- Use `FOR ALL TABLES` publication.  
- Sync payment secret tables.  
- Rely on web preview for offline proof (native is the real gate).
