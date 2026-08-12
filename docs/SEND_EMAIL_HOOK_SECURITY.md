# Send Email Auth Hook — security model & hardening

Aligned with Supabase’s HTTPS Auth Hook design: **JWT is off**; **Standard Webhooks signature is the gate**.

---

## Threats you listed → our posture

| Risk | Status in Peeke `send-email` |
|------|------------------------------|
| Public URL + `verify_jwt: false` | **Required.** Mitigated by **signature verification first**; failures return **401** with empty body |
| Forged POSTs → spam/phishing | Rejected if `webhook-signature` / timestamp fails (`standardwebhooks@1.0.0`) |
| Secret leakage in errors/logs | Logs are **codes only** (`webhook_verify_failed`, `resend_failed`); no tokens, no keys, no full payload |
| Auth token / OTP handling | Tokens used **in memory only**; never persisted; OTP not logged |
| Secure Email Change (two OTPs) | Implemented: current email uses `token` + `token_hash_new`; new email uses `token_new` + `token_hash` |
| Open redirect via `redirect_to` | **Allow-list**: `peeke-cmms-erp.pages.dev`, localhost only; else default login URL |
| Link tracking rewriting Auth URLs | Avoid Resend click-tracking for Auth; prefer plain links in HTML |
| Supply chain (`esm.sh`) | **Pinned** `standardwebhooks@1.0.0`; Resend via direct HTTPS API (no npm resend package) |
| Replay | Library verifies timestamp window per Standard Webhooks |
| Oversized body / abuse | Reject body **> 64 KB** |
| Unknown `email_action_type` | Allow-list only |
| Verbose errors to attacker | Empty JSON on error paths |

---

## Hardening checklist (ops)

- [ ] `RESEND_API_KEY` and `SEND_EMAIL_HOOK_SECRET` only in Supabase secrets — never git / Flutter
- [ ] Enable hook **only after** both secrets are set
- [ ] Generate hook secret in **Auth → Hooks**; paste full `v1,whsec_...` into secrets
- [ ] Verify Resend domain + SPF/DKIM/DMARC before production volume
- [ ] Disable link tracking on Auth templates in Resend if the option exists
- [ ] Monitor Resend for spikes, bounces, complaints
- [ ] Rotate Resend key + hook secret after any suspected leak
- [ ] Keep signup CAPTCHA / rate limits on Auth providers as abuse control
- [ ] Periodically re-test: valid signed request sends; unsigned → 401

---

## What we will not do

- Skip or soft-fail signature verification
- Log `token`, `token_hash`, or full webhook body
- Put mail credentials in the client
- Rely on “secret URL” obscurity as security

---

## Official model (summary)

Supabase documents HTTPS Auth Hooks around **Standard Webhooks**. Signature verification is the primary control when JWT verification is disabled. Implemented correctly, this path is the recommended way to send custom Auth email with Resend.
