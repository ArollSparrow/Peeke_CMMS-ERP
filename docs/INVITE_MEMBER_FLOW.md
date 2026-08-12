# Team member invite flow (testing phase)

## Mail provider

- **Resend / Custom SMTP / Send Email hook: OFF** for this building phase.
- Use **Supabase built-in Auth email** only (~**2 emails per hour** — expect delays).
- Dashboard checks:
  1. **Authentication → Hooks → Send Email** → **disabled**
  2. **Authentication → SMTP** → Custom SMTP **off**
- Edge Function `send-email` may remain deployed but is **not** used while the hook is off.

---

## Intended logic

```
Admin: Team → Send invite (work email + role)
        │
        ▼
organization_invites.status = pending
  (NOT yet in organization_members)
        │
        ▼
Supabase Auth invite email (built-in)
  → open link → set password (personal account)
  → redirect → /login
        │
        ▼
Invitee: Sign in with email + password  (must succeed)
        │
        ▼
PostAuthGate → rpc accept_pending_org_invites()
        │
        ▼
organization_members row created → status accepted
  → they appear under Team → Members
```

### Rules

| Step | Member? |
|------|---------|
| Invite saved / email sent | **No** — pending only |
| Password set via invite link | **No** until login |
| Successful sign-in + gate | **Yes** |

Auth **Users** list may show the email as soon as invite is issued. That is normal. Users ≠ org members.

### Existing accounts

If the email already has a **confirmed** Auth user: invite stays **pending** until they **sign in** once (no extra email required).

### Rate limit

If built-in mail fails or is delayed, Team UI may show a **shareable action_link** — same path: set password → sign in → member.

---

## Admin controls

- Cancel pending invite → `revoke_org_invite`
- Remove member → `remove_org_member`

---

## Later (production mail)

Re-enable Custom SMTP or Send Email hook + Resend when ready. Until then stay on built-in for testing.
