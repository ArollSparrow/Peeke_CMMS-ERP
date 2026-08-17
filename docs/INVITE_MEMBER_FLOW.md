# Team member invite flow

## SaaS principle

**Tenant / organisation admins never use the Supabase dashboard.**  
All invite, cancel, residual Auth cleanup, and membership attach runs in-app via Edge Functions (service role) + RPCs.

## Primary path for members: **email**

Invitees join by opening the **Accept invitation** link from their inbox.  
The WhatsApp/SMS **action_link** is an **admin-only fallback** when Auth mail is rate-limited or delayed — it is shown on the Team screen to elevated roles, not to the invitee as the normal path.

## Mail provider

- Prefer production SMTP / Resend when available.
- Built-in Auth email is rate-limited (~2/hour) — delays are normal in testing.
- When mail cannot deliver, the app returns a shareable **action_link** for admins only.

## Intended logic

```
Admin: Team → Send invite (work email + role)
        │
        ▼
Edge Function invite-org-member (service role)
  • verify elevated role in org
  • delete prior pending invites for this email in this org
  • if Auth user exists with ZERO memberships → delete residual Auth user
  • insert organization_invites (pending)
  • inviteUserByEmail (preferred) OR generateLink → action_link (admin fallback)
        │
        ▼
Invitee opens **email** link signed out (private window if needed)
  → redirect /accept-invite#access_token=…&type=invite
  → session recovered (implicit flow on web)
  → set password + name → accept_pending_org_invites()
        │
        ▼
organization_members row → invite status accepted
```

## Web Auth note (session from mail)

`inviteUserByEmail` redirects with **implicit** hash tokens (`#access_token`, `type=invite`).  
Flutter web uses `AuthFlowType.implicit` + `detectSessionInUri` so that session is established on Accept invite.  
PKCE-only clients leave `currentUser` null and show “Link not active yet” even with a valid mail link.

## Critical rules

1. **Never open the invite link while signed in as the owner** (or any other account). That caused the “Kiai became owner” incident: password/name updated on the wrong Auth user.
2. Email links use `type=invite` and establish the **invitee** session.
3. For emails that already have a confirmed Auth user, Supabase often cannot send another invite email; the app returns an **action_link** for **admin** to share if needed.
4. **Cancel invite** (in-app only) → Edge Function `revoke-org-invite`: deletes invite row + residual Auth user when the email is not a member of any organisation.
5. **Re-invite** (in-app only) → Edge Function `invite-org-member` also purges residual Auth users before calling `inviteUserByEmail`, so mail can hit the inbox again without any dashboard step.

## Accept-invite guards

- Session email must match a **pending** `organization_invites` row.
- If the signed-in user has no pending invite for their email, join is blocked (wrong session).
- Expired / already-used links show a clear error; admin must send a new invite email.

## Admin controls (all in-app)

| Action | Implementation |
|--------|----------------|
| Send invite | `functions.invoke('invite-org-member')` |
| Cancel pending invite | `functions.invoke('revoke-org-invite')` |
| Remove member | RPC `remove_org_member` |

## Residual Auth cleanup (automated)

`inviteUserByEmail` / `generateLink` can leave an Auth user even when the invite email never arrives. That residual blocks the next mail send.

**Cancel path**

1. Elevated caller cancels from Team UI.
2. `revoke-org-invite` deletes the pending row.
3. If email has no `organization_members` and no other pending invites → `auth.admin.deleteUser`.

**Send / re-invite path**

1. Elevated caller sends invite from Team UI.
2. `invite-org-member` removes prior pending rows for that email in the org.
3. If Auth user exists with **zero** memberships → delete residual Auth user.
4. Insert new pending invite + attempt `inviteUserByEmail` (fresh user → mail can deliver).
5. On mail failure / rate limit → return `action_link` for **admin** WhatsApp/SMS only.

No tenant admin ever opens Authentication → Users in the dashboard.

## Deploy

```bash
supabase functions deploy invite-org-member --project-ref <your-ref>
supabase functions deploy revoke-org-invite --project-ref <your-ref>
```

Both functions use the project’s built-in `SUPABASE_SERVICE_ROLE_KEY` (no secrets in the Flutter app).

## Required Supabase URL config (platform, once)

| Field | Value |
|-------|--------|
| Site URL | `https://peeke-cmms-erp.pages.dev` |
| Redirect URLs | `https://peeke-cmms-erp.pages.dev/**` |
| | `http://localhost:*/**` (dev) |
