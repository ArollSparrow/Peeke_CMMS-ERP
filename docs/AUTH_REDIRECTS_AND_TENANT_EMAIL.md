# Auth redirects & tenant-branded email

## Why invite links showed “page not found”

1. Invite `redirectTo` pointed at `/gate` (or another path).
2. Cloudflare Pages only serves files that exist unless SPA fallback is active.
3. Our build writes `build/web/_redirects` with `/* /index.html 200`, but Auth must still land on a **path we know works**.

**Fix in app / Edge Function:** invite redirects now use:

`https://peeke-cmms-erp.pages.dev/login`

After the user sets a password, they hit login; signed-in users are routed to `/gate` → home / org.

### Required Supabase dashboard settings

**Authentication → URL configuration**

| Field | Value |
|-------|--------|
| Site URL | `https://peeke-cmms-erp.pages.dev` |
| Redirect URLs | `https://peeke-cmms-erp.pages.dev/**` |
| | `http://localhost:*/**` (dev) |

Without these, Supabase may refuse the redirect or send users to a dead URL.

Re-send invites after updating Site URL / Redirect URLs so new links use `/login`.

---

## Team admin controls (implemented)

| Action | How |
|--------|-----|
| Send invite | Team → email + role → Edge Function + Auth invite email |
| Cancel invite | Team → pending invite → cancel icon → `revoke_org_invite` |
| Remove member | Team → member → remove icon → `remove_org_member` (not sole owner, not self) |
| Re-add | Send invite again (or they register with same email) |

---

## Tenant-branded email (instead of raw Supabase mail)

Today emails are sent by **Supabase Auth** (default template, “from” is Supabase/project SMTP).

### Path to real tenant branding

```
Admin invites
    → Edge Function (service role)
    → auth.admin.generateLink({ type: 'invite', email })
    → YOUR mail provider (Resend / SendGrid / Cloudflare Email Routing + Worker)
    → HTML template with org name, Peeke sky/navy/teal, custom From:
```

| Piece | Role |
|-------|------|
| **Supabase** | Issue secure invite/confirm tokens via Admin API (`generateLink`) — no custom SMTP required on Auth |
| **Edge Function** | Orchestrate: check admin, write `organization_invites`, call `generateLink`, call mail API |
| **Resend / similar** | Deliver branded HTML; free tier is enough to start |
| **Cloudflare** | Optional: Workers for webhooks, Email Routing, or store templates on Pages |
| **Webhook** | Optional later: Supabase Database Webhook on `organization_invites` INSERT → Worker → send mail |

### Recommended order

1. **Now:** Keep Auth invite email + correct redirect (done).
2. **Soon:** Custom Auth email templates in Supabase dashboard (logo, copy) — still “from” Supabase unless custom SMTP.
3. **Production:** `generateLink` + Resend with `from: invites@yourdomain.com` and org-aware HTML.
4. **Scale:** Per-tenant SMTP / domain only if enterprise customers demand it (complex; store encrypted settings server-side only).

### Security notes

- Never put Resend/SMTP secrets in the Flutter app.
- Edge Function + service role only.
- Rate-limit invites per org.
- Webhooks must verify signatures (Supabase webhook secret / Cloudflare).

---

## Manual check after dashboard URL fix

1. Team → Cancel old pending invites (or leave them).
2. Send invite again to a test Gmail.
3. Open link → should reach **peeke-cmms-erp.pages.dev/login** (not a 404).
4. Set password / sign in → org membership attaches via `accept_pending_org_invites`.
