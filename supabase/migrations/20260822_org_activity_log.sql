-- Organisation activity log (team audit trail).
CREATE TABLE IF NOT EXISTS public.organization_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  summary text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS organization_activity_org_created_idx
  ON public.organization_activity (organization_id, created_at DESC);

ALTER TABLE public.organization_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS organization_activity_select_elevated ON public.organization_activity;
CREATE POLICY organization_activity_select_elevated
  ON public.organization_activity
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.organization_id = organization_activity.organization_id
        AND m.user_id = auth.uid()
        AND m.role IN ('owner', 'system_admin', 'admin', 'ceo', 'general_manager')
    )
  );

CREATE OR REPLACE FUNCTION public.log_org_activity(
  p_organization_id uuid,
  p_action text,
  p_summary text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_role text;
  v_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_action IS NULL OR length(trim(p_action)) = 0 THEN
    RAISE EXCEPTION 'action required';
  END IF;
  IF p_summary IS NULL OR length(trim(p_summary)) = 0 THEN
    RAISE EXCEPTION 'summary required';
  END IF;

  SELECT role INTO v_role
  FROM public.organization_members
  WHERE organization_id = p_organization_id
    AND user_id = v_caller;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Not a member of this organisation';
  END IF;

  INSERT INTO public.organization_activity (
    organization_id, actor_user_id, action, summary, metadata
  ) VALUES (
    p_organization_id,
    v_caller,
    lower(trim(p_action)),
    trim(p_summary),
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_org_activity(uuid, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_org_activity(uuid, text, text, jsonb) TO authenticated;

-- Enrich ownership transfer with an activity row.
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

  INSERT INTO public.organization_activity (
    organization_id, actor_user_id, action, summary, metadata
  ) VALUES (
    p_organization_id,
    v_caller,
    'ownership_transferred',
    'Ownership transferred',
    jsonb_build_object(
      'previous_owner_user_id', v_caller,
      'new_owner_user_id', p_new_owner_user_id
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.transfer_org_ownership(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transfer_org_ownership(uuid, uuid) TO authenticated;
