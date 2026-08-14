-- Applied live 2026-08-14 on tappfahlaiixctyliesz
-- Org roles, departments, personal details — see docs/ORG_ROLES_AND_DEPARTMENTS.md

ALTER TABLE public.organization_members
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS job_title text,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Role check + departments tables + RPCs applied via dashboard SQL
-- (create_organization seeds 8 depts; owner → IT HoD)
-- list_org_team, update_org_member_details, set_org_member_departments,
-- update_my_org_profile, seed_organization_departments
