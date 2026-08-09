-- 014_wo_parts_inventory_po_link.sql
-- Applied on project tappfahlaiixctyliesz
-- Links WO parts ↔ inventory issue + purchase orders

-- 1) purchase_orders.work_order_id (nullable FK)
ALTER TABLE public.purchase_orders
  ADD COLUMN IF NOT EXISTS work_order_id uuid REFERENCES public.work_orders(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_purchase_orders_work_order_id
  ON public.purchase_orders (work_order_id)
  WHERE work_order_id IS NOT NULL;

-- 2) work_order_parts.purchase_order_id (soft link while status still pending)
ALTER TABLE public.work_order_parts
  ADD COLUMN IF NOT EXISTS purchase_order_id uuid REFERENCES public.purchase_orders(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_work_order_parts_purchase_order_id
  ON public.work_order_parts (purchase_order_id)
  WHERE purchase_order_id IS NOT NULL;

-- 3) issue_wo_part — atomic stock deduct + mark issued + activity event
CREATE OR REPLACE FUNCTION public.issue_wo_part(
  p_wo_part_id uuid,
  p_performed_by text DEFAULT NULL
)
RETURNS public.work_order_parts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_part public.work_order_parts;
  v_wo public.work_orders;
BEGIN
  SELECT * INTO v_part FROM public.work_order_parts WHERE id = p_wo_part_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'WO part not found';
  END IF;
  IF NOT public.is_org_member(v_part.organization_id) THEN
    RAISE EXCEPTION 'Not a member of this organization';
  END IF;
  IF v_part.source <> 'internal' THEN
    RAISE EXCEPTION 'Only internal parts can be issued from stock';
  END IF;
  IF v_part.procurement_status = 'issued' THEN
    RAISE EXCEPTION 'Part already issued';
  END IF;
  IF v_part.spare_part_id IS NULL THEN
    RAISE EXCEPTION 'Link a catalogue spare part before issuing from stock';
  END IF;

  SELECT * INTO v_wo FROM public.work_orders WHERE id = v_part.work_order_id;

  PERFORM public.apply_stock_movement(
    p_org := v_part.organization_id,
    p_part_id := v_part.spare_part_id,
    p_txn_type := 'issue',
    p_quantity := v_part.qty_required,
    p_unit_cost := v_part.unit_cost,
    p_reference := COALESCE(v_wo.wo_number, v_part.work_order_id::text),
    p_work_order_id := v_part.work_order_id,
    p_notes := 'Issued to WO part ' || v_part.part_name,
    p_performed_by := p_performed_by
  );

  UPDATE public.work_order_parts
  SET procurement_status = 'issued',
      updated_at = now()
  WHERE id = p_wo_part_id
  RETURNING * INTO v_part;

  INSERT INTO public.work_order_events (
    organization_id, work_order_id, action, stage, to_status, actor, notes
  ) VALUES (
    v_part.organization_id,
    v_part.work_order_id,
    'issued',
    'parts',
    v_wo.status,
    p_performed_by,
    'Issued ' || v_part.qty_required::text || ' × ' || v_part.part_name
  );

  RETURN v_part;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.issue_wo_part(uuid, text) TO authenticated;

-- 4) Sync WO external parts when PO status advances
CREATE OR REPLACE FUNCTION public.sync_wo_parts_on_po_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.work_order_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- ordered → external pending parts become ordered
  IF NEW.status = 'ordered' AND (OLD.status IS DISTINCT FROM 'ordered') THEN
    UPDATE public.work_order_parts
    SET procurement_status = 'ordered',
        purchase_order_id = NEW.id,
        updated_at = now()
    WHERE work_order_id = NEW.work_order_id
      AND source = 'external'
      AND procurement_status = 'pending'
      AND (purchase_order_id IS NULL OR purchase_order_id = NEW.id);

    INSERT INTO public.work_order_events (
      organization_id, work_order_id, action, stage, to_status, notes
    ) VALUES (
      NEW.organization_id,
      NEW.work_order_id,
      'parts_ordered',
      'procurement',
      'parts_ordered',
      'PO ' || COALESCE(NEW.po_number, NEW.id::text) || ' ordered'
    );
  END IF;

  -- received / partially_received → those parts become received
  IF NEW.status IN ('received', 'partially_received')
     AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    UPDATE public.work_order_parts
    SET procurement_status = 'received',
        updated_at = now()
    WHERE work_order_id = NEW.work_order_id
      AND source = 'external'
      AND purchase_order_id = NEW.id
      AND procurement_status IN ('pending', 'ordered');

    INSERT INTO public.work_order_events (
      organization_id, work_order_id, action, stage, to_status, notes
    ) VALUES (
      NEW.organization_id,
      NEW.work_order_id,
      'received',
      'procurement',
      NEW.status,
      'PO ' || COALESCE(NEW.po_number, NEW.id::text) || ' received into stock'
    );
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_wo_parts_on_po ON public.purchase_orders;
CREATE TRIGGER trg_sync_wo_parts_on_po
  AFTER UPDATE OF status ON public.purchase_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_wo_parts_on_po_status();
