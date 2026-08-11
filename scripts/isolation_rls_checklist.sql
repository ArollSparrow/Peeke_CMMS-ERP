-- P0.2 Tenant isolation checklist (run in Supabase SQL editor as needed)
-- Goal: every organization_id table has RLS + policies; secrets not client-readable.

-- 1) Tables with organization_id and policy counts
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_on,
       c.relforcerowsecurity AS rls_forced,
       (SELECT count(*) FROM pg_policies p
         WHERE p.schemaname = 'public' AND p.tablename = c.relname) AS policies
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY c.relname;

-- 2) Secret columns must have no privileges for authenticated/anon
SELECT table_name, column_name, grantee, privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND column_name IN ('secret_key', 'webhook_secret')
  AND grantee IN ('authenticated', 'anon');
-- Expect: zero rows

-- 3) Manual two-tenant test (do after creating Org A and Org B users):
--    As user B: SELECT count(*) FROM clients;  -- must not see Org A rows
--    As user B: INSERT INTO clients (organization_id, name, ...) VALUES ('<org_a_id>', ...);
--               -- must fail RLS
-- Repeat for: systems, work_orders, work_requests, vendors, spare_parts,
--             purchase_orders, maintenance_records, payment_transactions.

-- 4) Payment secrets: authenticated SELECT * FROM organization_payment_settings
--    must not return secret_key / webhook_secret (column privilege denied).
