# Send Email Auth Hook (Option 2) — setup

Edge Function **`send-email`** is deployed on project `tappfahlaiixctyliesz` with Peeke branding (sky / navy / teal).

Until **Resend** + hook secrets are configured, Auth emails will fail at the hook (by design — no silent built-in fallback once the hook is enabled).

---

## 1. Create a Resend account

1. Sign up at https://resend.com  
2. Create an API key  
3. **Testing:** you can send *to your own signup email* using `from: onboarding@resend.dev`  
4. **Production:** add and verify your domain, then set `MAIL_FROM` e.g. `Peeke Automation <invites@yourdomain.com>`

---

## 2. Set Edge Function secrets

In **Supabase Dashboard → Project Settings → Edge Functions → Secrets** (or CLI):

| Secret | Value |
|--------|--------|
| `RESEND_API_KEY` | `re_...` from Resend |
| `SEND_EMAIL_HOOK_SECRET` | Generated when you enable the hook (step 3) — form `v1,whsec_...` |
| `MAIL_FROM` | Optional. Default in code: `Peeke Automation <onboarding@resend.dev>` |

---

## 3. Enable the Auth Hook

**Authentication → Hooks → Send Email**

| Field | Value |
|-------|--------|
| Enabled | On |
| Hook type | HTTPS |
| URL | `https://tappfahlaiixctyliesz.supabase.co/functions/v1/send-email` |
| Secret | Generate / copy → paste into `SEND_EMAIL_HOOK_SECRET` |

Keep **Email provider** enabled (hook handles sending; SMTP is not used while the hook is on).

---

## 4. What gets branded

| `email_action_type` | Subject / body |
|---------------------|----------------|
| `invite` | Team invite → set password |
| `signup` | Confirm registration |
| `recovery` | Password reset |
| `magiclink` | Sign-in link |
| others | Generic Peeke notification |

Confirmation links use:

`https://tappfahlaiixctyliesz.supabase.co/auth/v1/verify?token=...&type=...&redirect_to=...`

---

## 5. Test

1. Secrets set + hook enabled  
2. Team → Send invite to an email you control  
3. Check Resend dashboard **Emails** log  
4. Open link → set password → sign in → membership attaches  

Also check **Authentication → Logs** if the hook returns errors.

---

## 6. Roll back

Disable the Send Email hook in the dashboard to return to built-in / SMTP delivery.

---

## Security

- Never put `RESEND_API_KEY` or hook secret in the Flutter app or git  
- Function runs with `verify_jwt: false` because Auth uses **Standard Webhooks** signatures instead  
