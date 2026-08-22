-- Department management (create / rename / soft-deactivate).
-- Applied live on tappfahlaiixctyliesz 2026-08-22.
-- RLS remains SELECT-only; mutations via SECURITY DEFINER + is_org_admin.

ALTER TABLE public.organization_departments
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.create_org_department(
  p_organization_id uuid,
  p_name text,
  p_code text DEFAULT NULL
)
RETURNS public.organization_departments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_code text;
  v_name text;
  v_sort int;
  v_row public.organization_departments;
BEGIN
  IF NOT public.is_org_admin(p_organization_id) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  v_name := trim(p_name);
  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'name required';
  END IF;
  IF p_code IS NULL OR length(trim(p_code)) = 0 THEN
    v_code := lower(regexp_replace(v_name, '[^a-zA-Z0-9]+', '_', 'g'));
    v_code := trim(both '_' from v_code);
  ELSE
    v_code := lower(regexp_replace(trim(p_code), '[^a-zA-Z0-9_]+', '_', 'g'));
    v_code := trim(both '_' from v_code);
  END IF;
  IF v_code IS NULL OR length(v_code) < 2 THEN
    RAISE EXCEPTION 'invalid code';
  END IF;
  SELECT COALESCE(MAX(sort_order), 0) + 10 INTO v_sort
  FROM public.organization_departments
  WHERE organization_id = p_organization_id;
  INSERT INTO public.organization_departments (organization_id, code, name, sort_order, is_active)
  VALUES (p_organization_id, v_code, v_name, v_sort, true)
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.rename_org_department(
  p_department_id uuid,
  p_name text
)
RETURNS public.organization_departments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_org uuid;
  v_name text;
  v_row public.organization_departments;
BEGIN
  SELECT organization_id INTO v_org FROM public.organization_departments WHERE id = p_department_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'department not found'; END IF;
  IF NOT public.is_org_admin(v_org) THEN RAISE EXCEPTION 'not authorized'; END IF;
  v_name := trim(p_name);
  IF v_name IS NULL OR length(v_name) < 2 THEN RAISE EXCEPTION 'name required'; END IF;
  UPDATE public.organization_departments SET name = v_name WHERE id = p_department_id
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_org_department_active(
  p_department_id uuid,
  p_active boolean
)
RETURNS public.organization_departments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_org uuid;
  v_row public.organization_departments;
BEGIN
  SELECT organization_id INTO v_org FROM public.organization_departments WHERE id = p_department_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'department not found'; END IF;
  IF NOT public.is_org_admin(v_org) THEN RAISE EXCEPTION 'not authorized'; END IF;
  UPDATE public.organization_departments SET is_active = COALESCE(p_active, true) WHERE id = p_department_id
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_org_department(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rename_org_department(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_org_department_active(uuid, boolean) TO authenticated;
