# Invite email template (platform — once)

## Problem

Default Supabase **Invite user** mail uses `{{ .ConfirmationURL }}`:

```
https://<project>.supabase.co/auth/v1/verify?token=…&type=invite&redirect_to=https://peeke-cmms-erp.pages.dev/accept-invite
```

After verify, the browser often lands on **bare** `/accept-invite` with **no**
`#access_token` and **no** `?code=`. The Accept invite form then shows
“no invite session tokens”. This is independent of cancel/residual cleanup
and of the Team UI (those are fine).

Tenant / org admins never open the Supabase dashboard. **Platform** (Peeke)
sets the Invite template once for the project.

## Fix (Supabase Dashboard → Authentication → Email Templates → Invite user)

**Subject** (example):

```text
You're invited to join a team on Peeke
```

**Body** — put the token on **our** app so Flutter can call `verifyOTP`:

```html
<h2>Join your team on Peeke</h2>
<p>You have been invited to join an organisation on Peeke CMMS-ERP.</p>
<p>
  <a href="{{ .SiteURL }}/accept-invite?token_hash={{ .TokenHash }}&type=invite"
    >Accept invitation</a
  >
</p>
<p>If you did not expect this email, you can ignore it.</p>
```

**Site URL** (Authentication → URL configuration) must be:

```text
https://peeke-cmms-erp.pages.dev
```

**Redirect URLs** must include:

```text
https://peeke-cmms-erp.pages.dev/**
```

Optional: keep `redirect_to` from the Edge Function; it is not required when
the template uses `TokenHash` on `/accept-invite`.

## What the app does

1. Invitee opens:
   `https://peeke-cmms-erp.pages.dev/accept-invite?token_hash=…&type=invite`
2. `AcceptInviteScreen` calls `auth.verifyOTP(tokenHash: …, type: OtpType.invite)`.
3. Session is the invitee → set password / name → `accept_pending_org_invites`.

No tenant dashboard step. No reliance on hash fragments after `/auth/v1/verify`.

## After changing the template

1. Cancel any pending test invites in Team.
2. Send a **new** invite (old emails still use the old ConfirmationURL).
3. Open the **new** mail link once (private window if needed).
4. Expect **Invited as &lt;email&gt;** and an active join button.

## Admin action_link (fallback only)

When Auth SMTP is rate-limited, Team still shows a shareable `action_link` for
**org admins** only. Prefer fixing mail + this template so members join from
the inbox.
