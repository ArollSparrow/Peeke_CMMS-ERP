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
