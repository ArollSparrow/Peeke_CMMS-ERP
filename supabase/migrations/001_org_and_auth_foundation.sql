-- Mirrored from Supabase apply_migration: 001_org_and_auth_foundation
-- Project: tappfahlaiixctyliesz (Peeke CMMS-ERP)
-- See live project; this file is source-of-truth for local/CLI.

-- (Full SQL applied on 2026-08-01 via MCP)
-- Tables: organizations, profiles, organization_members
-- Helpers: is_org_member, is_org_admin, my_organization_ids, handle_new_user
-- RLS enabled on all three tables

-- Re-apply note: do not run blindly if already applied; use Supabase migration history.
