-- PowerSync Cloud replication surface (allowlist).
-- Apply on project tappfahlaiixctyliesz AFTER RLS is green on listed tables.
-- Do NOT use FOR ALL TABLES in production.
--
-- Adjust role name/password via secrets; never commit credentials.
-- See: https://docs.powersync.com/integrations/supabase/guide

-- 1) Replication role (run once; store password in vault / CI secrets)
-- CREATE ROLE powersync_role WITH REPLICATION LOGIN PASSWORD '...';
-- GRANT USAGE ON SCHEMA public TO powersync_role;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync_role;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync_role;

-- 2) Publication — offline foundation v1
-- DROP PUBLICATION IF EXISTS powersync;
-- CREATE PUBLICATION powersync FOR TABLE
--   public.organization_members,
--   public.organizations,
--   public.clients,
--   public.systems,
--   public.work_orders,
--   public.work_requests;
--
-- Later (after streams + RLS review):
--   public.work_order_parts,
--   public.work_order_events,
--   public.spare_parts,
--   ...

-- 3) Verify
-- SELECT * FROM pg_publication_tables WHERE pubname = 'powersync';

-- Placeholder so migration history records intent on this branch.
SELECT 1;
