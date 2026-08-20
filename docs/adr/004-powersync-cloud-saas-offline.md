# ADR 004 — PowerSync Cloud as offline sync plane (SaaS)

## Status

Accepted (bootstrap on `infra/powersync-cloud-bootstrap`).

## Context

Peeke requires offline-capable CMMS clients without weakening multi-tenancy.
`organization_id` + Postgres RLS are non-negotiable from day one.
Enterprise / SaaS buyers expect a SOC 2–oriented sync vendor rather than an
unattested self-hosted sync plane for v1.

## Decision

1. Use **PowerSync Cloud** (JourneyApps SaaS) as the sync plane.
2. Keep **Supabase Postgres + RLS** as the system of record for all writes.
3. Shape downloads with **Sync Streams** scoped via `organization_members`
   (`auth.user_id()`), never global buckets for tenant data.
4. Client SQLite schema includes **`organization_id` on every synced table**.
5. Uploads use the **user JWT** Supabase client (no service role on device).
6. Opt-in via `--dart-define=POWERSYNC_URL=...` so production web can stay
   online-only until streams and publication are live.

## Consequences

- Compliance: SOC 2 Type 2 reports available on Team/Enterprise plans; DPA/BAA
  as required for GDPR/HIPAA deals.
- Ops: PowerSync operates the sync service; Peeke owns publication allowlist,
  stream YAML, and RLS.
- Product: UI cutover is domain-by-domain (clients/systems first).

## References

- `powersync/sync-streams.yaml`
- `lib/infra/sync/`
- `supabase/migrations/20260820_powersync_publication.sql`
- `scripts/isolation_rls_checklist.sql`
