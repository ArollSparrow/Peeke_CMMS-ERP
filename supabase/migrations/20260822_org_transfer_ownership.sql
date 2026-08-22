-- Transfer organisation ownership (owner-only). Previous owner becomes system_admin.
CREATE OR REPLACE FUNCTION public.transfer_org_ownership(
  p_organization_id uuid,
  p_new_owner_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_caller_role text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role
  FROM public.organization_members
  WHERE organization_id = p_organization_id
    AND user_id = v_caller;

  IF v_caller_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Only the organisation owner can transfer ownership';
  END IF;

  IF p_new_owner_user_id = v_caller THEN
    RAISE EXCEPTION 'You are already the owner';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organization_members
    WHERE organization_id = p_organization_id
      AND user_id = p_new_owner_user_id
  ) THEN
    RAISE EXCEPTION 'New owner must already be a member of this organisation';
  END IF;

  UPDATE public.organization_members
  SET role = 'system_admin'
  WHERE organization_id = p_organization_id
    AND user_id = v_caller;

  UPDATE public.organization_members
  SET role = 'owner'
  WHERE organization_id = p_organization_id
    AND user_id = p_new_owner_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.transfer_org_ownership(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transfer_org_ownership(uuid, uuid) TO authenticated;
