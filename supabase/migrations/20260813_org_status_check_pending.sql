-- organizations_status_check previously only allowed active|suspended|trial
-- Hard gate create_organization inserts status = 'pending' and failed with a generic client error.
-- Applied live 2026-08-13 on tappfahlaiixctyliesz.

ALTER TABLE public.organizations DROP CONSTRAINT IF EXISTS organizations_status_check;

ALTER TABLE public.organizations
  ADD CONSTRAINT organizations_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'testing'::text,
    'active'::text,
    'rejected'::text,
    'suspended'::text,
    'trial'::text
  ]));
