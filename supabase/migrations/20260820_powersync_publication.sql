-- PowerSync Cloud replication surface (allowlist).
-- Project: tappfahlaiixctyliesz (Peeke CMMS-ERP)
--
-- Applied live (2026-08-21) via ops on infra/powersync-cloud-bootstrap:
--   - ROLE powersync_role (REPLICATION, BYPASSRLS, LOGIN)
--   - PUBLICATION powersync FOR TABLE (allowlist — NOT FOR ALL TABLES):
--       organization_members, organizations, clients, systems,
--       work_orders, work_requests
--
-- Password is NOT in git. Retrieve from ops vault / the session that created the role.
-- Connection URI for PowerSync Dashboard (Direct, not pooler):
--   postgresql://powersync_role:PASSWORD@db.tappfahlaiixctyliesz.supabase.co:5432/postgres
--
-- See: https://docs.powersync.com/integrations/supabase/guide
-- See: docs/POWERSYNC_OPS_RUNBOOK.md

-- Idempotent re-apply (safe if already present):
-- DO $$
-- BEGIN
--   IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_role') THEN
--     CREATE ROLE powersync_role WITH REPLICATION BYPASSRLS LOGIN PASSWORD '...';
--   END IF;
-- END $$;
-- GRANT USAGE ON SCHEMA public TO powersync_role;
-- GRANT SELECT ON TABLE
--   public.organization_members, public.organizations, public.clients,
--   public.systems, public.work_orders, public.work_requests
-- TO powersync_role;
-- DROP PUBLICATION IF EXISTS powersync;
-- CREATE PUBLICATION powersync FOR TABLE
--   public.organization_members, public.organizations, public.clients,
--   public.systems, public.work_orders, public.work_requests;

-- Verify:
-- SELECT * FROM pg_publication_tables WHERE pubname = 'powersync';
-- SELECT rolname, rolreplication, rolbypassrls FROM pg_roles WHERE rolname = 'powersync_role';

SELECT 1;
