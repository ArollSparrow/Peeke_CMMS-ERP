-- 015_wo_approval_stages.sql
-- Slice C: optional approval gate + awaiting_parts while procurement in flight
-- Applied on project tappfahlaiixctyliesz

ALTER TABLE public.work_orders
  ADD COLUMN IF NOT EXISTS approved_by text,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS approval_notes text;

COMMENT ON COLUMN public.work_orders.approved_by IS 'Who approved pending_approval → open';
COMMENT ON COLUMN public.work_orders.approval_notes IS 'Notes from approve or reject of pending_approval';

-- Status vocabulary (text, no CHECK constraint):
--   open | pending_approval | awaiting_parts | in_progress | on_hold | completed | cancelled
