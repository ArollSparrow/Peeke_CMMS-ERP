# Team member invite flow

## Mail provider

- Prefer production SMTP / Resend when available.
- Built-in Auth email is rate-limited (~2/hour) — delays are normal in testing.

## Intended logic

```
Admin: Team → Send invite (work email + role)
        │
        ▼
organization_invites.status = pending
  (NOT yet in organization_members)
        │
        ▼
Auth invite email (type=invite)  OR  shareable action_link (WhatsApp/SMS)
  → invitee opens link **signed out** (private window if needed)
  → /accept-invite → set password + name
  → accept_pending_org_invites()
        │
        ▼
organization_members row → invite status accepted
```

## Critical rules

1. **Never open the shareable link while signed in as the owner** (or any other account). That is what caused the “Kiai became owner” incident: password/name updated on the wrong Auth user.
2. Email links use `type=invite` and establish the **invitee** session.
3. For emails that already have a confirmed Auth user, Supabase often cannot send another invite email; the app returns an **action_link** (`type=invite` preferred, else `magiclink` → `/accept-invite`). Share that only with the invitee.
4. **Cancel invite** removes the `organization_invites` row and, if that email is **not a member of any organisation**, deletes the residual Auth user so a later invite can hit the inbox again via `inviteUserByEmail`.

## Accept-invite guards

- Session email must match a **pending** `organization_invites` row.
- If the signed-in user has no pending invite for their email, join is blocked (wrong session).

## Admin controls

- Cancel pending invite → Edge Function `revoke-org-invite` (invite row + residual Auth cleanup)
- Remove member → `remove_org_member`

## Residual Auth cleanup (why cancel must use the edge function)

`inviteUserByEmail` / `generateLink` creates an Auth user even when the invite email never arrives. A plain RPC that only deletes `organization_invites` leaves that Auth user behind. The next invite then cannot send mail and falls back to the WhatsApp/SMS action_link.

**Cancel path (client):** `functions.invoke('revoke-org-invite', { invite_id })`

**Edge function responsibilities:**

1. Verify caller is elevated in the invite’s organisation.
2. Delete the pending `organization_invites` row.
3. If the invitee email has **no** `organization_members` row and **no** other pending invites → `auth.admin.deleteUser` for that residual Auth user.
4. Return `{ ok, email, auth_user_deleted }`.

After a successful cancel with `auth_user_deleted: true`, a fresh **Send invite** can create a clean Auth user and deliver the invite email again.

## Deploy note

```bash
supabase functions deploy revoke-org-invite --project-ref <your-ref>
```

Ensure the function has access to `SUPABASE_SERVICE_ROLE_KEY` (default on hosted projects).
