# PowerSync Cloud bootstrap (Peeke)

**Working branch:** `infra/powersync-cloud-bootstrap`

Infrastructure foundation is on production (`redesign/gloss-restrained-full-depth` via #33).  
Ops + isolation continue on **this branch** until streams are proven.

## Ops status

| Step | Status |
|------|--------|
| PowerSync Cloud instance | **Manual** — [runbook](POWERSYNC_OPS_RUNBOOK.md) |
| Publication allowlist on `tappfahlaiixctyliesz` | **Done** (6 tables) |
| Deploy `powersync/sync-streams.yaml` | **Manual** — dashboard Validate → Deploy |
| Two-tenant isolation | Checklist: `scripts/powersync_two_tenant_isolation.sql` |

Full steps: **[POWERSYNC_OPS_RUNBOOK.md](POWERSYNC_OPS_RUNBOOK.md)**.

## Policy: every push gets a dry run

Push runs **Dry run (analyze)** then **Cloudflare Pages** deploy.

## What is on the branch

| Artifact | Purpose |
|----------|---------|
| `powersync/sync-streams.yaml` | Membership-scoped streams (clients/systems/work) |
| `lib/infra/sync/*` | Schema, connector, lifecycle, status |
| Dual-read providers | Clients, systems, work orders/requests |
| Publication | Applied live; migration documents intent |
| `docs/POWERSYNC_OPS_RUNBOOK.md` | Dashboard + connection steps |

Without `POWERSYNC_URL`, the app is online-only Supabase.

## Local run with sync

```bash
flutter run --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com
```

## Preview URL

https://infra-powersync-cloud-bootstrap.peeke-cmms-erp.pages.dev
