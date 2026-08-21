-- PowerSync + RLS two-tenant isolation checklist
-- Run in Supabase SQL editor (service role / postgres) for setup verification,
-- then validate downloads as two distinct authenticated users in the app.
--
-- Goal: User in Org B must never receive Org A rows via PowerSync streams
-- (membership-scoped queries) or via direct Supabase selects (RLS).

-- ---------------------------------------------------------------------------
-- A) Inventory orgs + membership
-- ---------------------------------------------------------------------------
SELECT o.id, o.name, o.slug, o.status,
       (SELECT count(*) FROM organization_members m WHERE m.organization_id = o.id) AS members
FROM organizations o
ORDER BY o.created_at;

SELECT m.organization_id, o.slug, m.user_id, m.role
FROM organization_members m
JOIN organizations o ON o.id = m.organization_id
ORDER BY o.slug, m.role;

-- ---------------------------------------------------------------------------
-- B) Row counts per tenant (baseline)
-- ---------------------------------------------------------------------------
SELECT 'clients' AS t, organization_id, count(*) FROM clients GROUP BY 2
UNION ALL
SELECT 'systems', organization_id, count(*) FROM systems GROUP BY 2
UNION ALL
SELECT 'work_orders', organization_id, count(*) FROM work_orders GROUP BY 2
UNION ALL
SELECT 'work_requests', organization_id, count(*) FROM work_requests GROUP BY 2
ORDER BY 1, 2;

-- ---------------------------------------------------------------------------
-- C) Publication surface (must be allowlist, not FOR ALL TABLES)
-- ---------------------------------------------------------------------------
SELECT pubname, puballtables FROM pg_publication WHERE pubname = 'powersync';
-- Expect: puballtables = false

SELECT tablename FROM pg_publication_tables WHERE pubname = 'powersync' ORDER BY 1;
-- Expect exactly:
--   clients, organization_members, organizations, systems, work_orders, work_requests

-- ---------------------------------------------------------------------------
-- D) Manual app / PowerSync test (after streams deployed)
-- ---------------------------------------------------------------------------
-- 1. User A (member of Org A only): sign in with POWERSYNC_URL set.
--    Confirm local SQLite only has Org A clients/systems/WOs.
-- 2. User B (member of Org B only): sign in on a clean profile / after logout clear.
--    Confirm local SQLite has zero Org A rows.
-- 3. User with membership in both orgs: may download both; switching active org
--    in UI must filter lists by organization_id (providers already do).
-- 4. Attempt write as User B with organization_id = Org A → must fail RLS.

-- Optional: seed a marker client on Org A only, then assert User B never sees it.
-- (Do not leave test markers in production without cleanup.)
