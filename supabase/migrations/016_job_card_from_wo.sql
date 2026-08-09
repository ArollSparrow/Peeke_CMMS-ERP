-- 016_job_card_from_wo.sql
-- Slice D: maintenance record (job card) + downtime linked from WO complete

ALTER TABLE public.maintenance_records
  ADD COLUMN IF NOT EXISTS work_order_id uuid REFERENCES public.work_orders(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_records_work_order_id
  ON public.maintenance_records (work_order_id)
  WHERE work_order_id IS NOT NULL;

ALTER TABLE public.maintenance_records
  ALTER COLUMN system_id DROP NOT NULL;

ALTER TABLE public.downtime_events
  ADD COLUMN IF NOT EXISTS work_order_id uuid REFERENCES public.work_orders(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_downtime_events_work_order_id
  ON public.downtime_events (work_order_id)
  WHERE work_order_id IS NOT NULL;
