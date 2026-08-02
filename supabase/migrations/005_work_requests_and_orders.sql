-- Phase 2: Work requests + Work orders (applied on tappfahlaiixctyliesz)
-- See Supabase migration 005_work_requests_and_orders

-- Tables work_requests, work_orders with org RLS
-- RPCs next_wr_number(p_org), next_wo_number(p_org)
-- Statuses WR: pending|approved|rejected|converted|cancelled
-- Statuses WO: open|in_progress|on_hold|completed|cancelled
