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

-- 2) Publication — offline priority v1 only
-- DROP PUBLICATION IF EXISTS powersync;
-- CREATE PUBLICATION powersync FOR TABLE
--   public.organization_members,
--   public.organizations,
--   public.clients,
--   public.systems;
--
-- Later (after streams + RLS review):
--   public.work_orders,
--   public.work_requests,
--   public.spare_parts,
--   ...

-- 3) Verify
-- SELECT * FROM pg_publication_tables WHERE pubname = 'powersync';

-- Placeholder so migration history records intent on this branch.
SELECT 1;
