# Team member invite flow

## SaaS principle

**Tenant / organisation admins never use the Supabase dashboard.**  
All invite, cancel, residual Auth cleanup, and membership attach runs in-app via Edge Functions (service role) + RPCs.

**Platform** configures Auth Site URL, Redirect URLs, and the **Invite user**
email template once (see `docs/AUTH_INVITE_EMAIL_TEMPLATE.md`).

## Primary path for members: **email**

Invitees join by opening the **Accept invitation** link from their inbox.  
That link must be:

`https://peeke-cmms-erp.pages.dev/accept-invite?token_hash=…&type=invite`

(not only `/auth/v1/verify` → bare `/accept-invite`).

The WhatsApp/SMS **action_link** is an **admin-only fallback** when Auth mail is rate-limited.

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
  • inviteUserByEmail (Auth sends mail using Invite template)
        │
        ▼
Invitee opens email link (token_hash on /accept-invite)
  → verifyOTP(type: invite)
  → set password + name → accept_pending_org_invites()
        │
        ▼
organization_members row → invite status accepted
```

## Critical rules

1. **Never open the invite link while signed in as the owner** (or any other account).
2. Platform Invite template must use `TokenHash` on `/accept-invite` (not only ConfirmationURL).
3. **Cancel invite** → `revoke-org-invite` (row + residual Auth when safe).
4. **Re-invite** → residual purge then `inviteUserByEmail` so mail can deliver again.

## Accept-invite guards

- Session email must match a **pending** `organization_invites` row.
- Wrong session (owner) is blocked.
- Expired / already-used links show a clear error.

## Admin controls (all in-app)

| Action | Implementation |
|--------|----------------|
| Send invite | `functions.invoke('invite-org-member')` |
| Cancel pending invite | `functions.invoke('revoke-org-invite')` |
| Remove member | RPC `remove_org_member` |

## Deploy

```bash
supabase functions deploy invite-org-member --project-ref <your-ref>
supabase functions deploy revoke-org-invite --project-ref <your-ref>
```
