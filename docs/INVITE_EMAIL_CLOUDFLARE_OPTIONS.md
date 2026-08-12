# Making team invites real — Cloudflare & alternatives

Exploration date: 2026-08-12  
Context: Built-in Supabase mail only reliably reaches **Supabase org team** addresses. External invitees often get nothing, while Auth still creates **Users**.

---

## What Cloudflare can (and cannot) do for us

### 1. Cloudflare Email Service — **Email Sending** (public beta, 2026)

| Item | Detail |
|------|--------|
| Purpose | Outbound **transactional** mail (invites, resets, OTPs) |
| Plan | **Workers Paid** required |
| Domain | Must onboard your domain under Email Service |
| APIs | Workers binding `env.EMAIL.send()`, **REST API**, **SMTP** |
| SMTP | `smtp.mx.cloudflare.net:465`, user `api_token`, password = CF API token with **Email Sending: Edit** |

**Why it matters for Peeke:** SMTP from Cloudflare can be pasted straight into **Supabase → Auth → SMTP**. Then *all* Auth mails (invite, confirm, reset) go through Cloudflare with your domain — no Resend account required if you already pay for Workers and own a domain.

Docs: https://developers.cloudflare.com/email-service/

### 2. Cloudflare Email Routing (free)

| Item | Detail |
|------|--------|
| Purpose | **Inbound** routing (`support@yourdomain` → Gmail / Worker) |
| Outbound | Very limited: Email Workers can send only to **verified** destination addresses on the routing setup — **not** suitable for inviting arbitrary member emails |

Useful later for `invites@peeke…` inbox, not for blasting invites.

### 3. Cloudflare “webhooks” in the API we have access to

| Product | Role for invites |
|---------|------------------|
| **Alerting webhooks** | Infra/account alerts only — **not** end-user mail |
| **Data Security posture webhooks** | Security events — **not** invites |
| **Workers Deploy Hooks** | CI/deploy triggers — **not** invites |
| **Queues + Email Sending events** | After CF Email Sending is live: delivery lifecycle events for monitoring |

**Conclusion:** There is no free Cloudflare “webhook that sends Gmail to teammates.” Real outbound mail needs **Email Sending** (paid Workers) or a third-party ESP (Resend, etc.).

### 4. Cloudflare Pages (already in use)

Hosts `peeke-cmms-erp.pages.dev`. SPA `_redirects` already set. Auth redirect URLs must keep pointing here. Pages alone does **not** send email.

---

## Supabase-native ways to make invites real

### Option A — Custom SMTP (simplest production fix)

Configure in **Dashboard → Authentication → SMTP**:

| Provider | Notes |
|----------|--------|
| **Resend** | Free tier, quick domain verify, official Supabase SMTP guide |
| **Cloudflare Email Service SMTP** | If domain + Workers Paid: host `smtp.mx.cloudflare.net`, port `465` |
| SendGrid / SES / Postmark | Also fine |

After SMTP is on, existing `inviteUserByEmail` / Auth templates deliver to **any** address (subject to ESP reputation).

### Option B — Send Email Auth Hook (maximum branding)

Supabase **Send Email** hook (Free plan) replaces built-in mail:

```
Auth event (invite / signup / recovery)
  → HTTPS hook (Supabase Edge Function or Cloudflare Worker)
  → verify Standard Webhooks secret
  → send via Resend API or CF EMAIL binding
  → Peeke HTML template (sky / navy / teal, org name)
```

Covers **all** auth emails, not only Team invites.  
Docs: https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook

### Option C — App-owned invite only (current + share link)

What we have today:

1. `organization_invites` row (pending)
2. Edge Function `invite-org-member` → `generateLink` + optional Auth invite
3. UI **Copy invite link** when SMTP cannot deliver
4. Membership only after password + sign-in (`accept_pending_org_invites`)

Works without any ESP; admin shares link via WhatsApp/SMS.

---

## Recommended path for Peeke (pragmatic)

| Phase | Action | Cost |
|-------|--------|------|
| **Now** | Keep copy-link + pending-until-signin | Free |
| **Next (real inboxes)** | Add **Resend** (or CF Email SMTP if domain/Workers Paid ready) as Supabase **Custom SMTP** | Free–low |
| **Polish** | Auth email templates (logo, Peeke Automation copy) in Supabase dashboard | Free |
| **Brand control** | Optional Send Email Hook → Worker → CF Email / Resend HTML | Low |

Avoid relying on Cloudflare **Alerting** or **Email Routing alone** for member invites — wrong product surface.

---

## Architecture sketch (target)

```
[Team UI] Send invite
    │
    ├─► organization_invites (pending)
    │
    └─► invite-org-member (Edge Function)
            │
            ├─► auth.admin.generateLink(type: invite)
            │
            └─► Auth sends mail via:
                    Custom SMTP ──► Resend  or  Cloudflare smtp.mx.cloudflare.net
                 OR Send Email Hook ──► Worker ──► env.EMAIL.send() / Resend API

Invitee: open link → set password → sign in
    └─► accept_pending_org_invites() → organization_members
```

---

## Prerequisites checklist before “real” mail

- [ ] Domain you control (e.g. `peeke.africa` or similar) — needed for SPF/DKIM
- [ ] Either Resend account **or** Cloudflare Email Sending onboarded (Workers Paid)
- [ ] Supabase Auth Site URL + Redirect URLs (already set to pages.dev)
- [ ] Custom SMTP or Send Email Hook configured
- [ ] Test with a non-team Gmail and confirm Auth logs + inbox

---

## What we will **not** do

- Promise delivery via free Supabase SMTP to arbitrary Gmail addresses
- Use Cloudflare Alerting webhooks as invite transport
- Put mail API secrets in the Flutter client

---

## Next implementation step (when you say go)

1. You create Resend (or confirm CF Email Sending + domain).
2. We wire **Supabase Custom SMTP** settings (you paste secrets in dashboard; we don’t store them in git).
3. Re-test Team invite → external inbox.
4. Optionally brand Auth templates / later Hook for full HTML control.
