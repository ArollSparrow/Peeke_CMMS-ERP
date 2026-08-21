# PowerSync Cloud bootstrap (Peeke)

**Working branch:** `infra/powersync-cloud-bootstrap`

## Ready for last-mile (native-only)

Infrastructure is in place. **PowerSync Cloud free accounts can idle-deactivate after ~1 week** — so:

1. Keep engineering/docs on this branch.  
2. Sign up + connect + deploy streams **only when you can test the same day on Android or iOS**.  
3. Web/Cloudflare preview stays online-only (no `POWERSYNC_URL` required).

Full last-mile steps: **[POWERSYNC_OPS_RUNBOOK.md](POWERSYNC_OPS_RUNBOOK.md)**.

## Status

| Step | Status |
|------|--------|
| App dual-read + schema + connector | Done |
| Publication allowlist on Supabase | Done |
| Streams YAML in repo | Done |
| PowerSync Cloud signup / instance | **Last** — when ready to test native |
| Deploy streams + two-tenant device test | **Last** — Android/iOS |

## Sign up (when ready)

https://accounts.powersync.com/portal/powersync-signup  
Then: https://dashboard.powersync.com/

## Local native run (after instance exists)

```bash
flutter run -d android --dart-define=POWERSYNC_URL=https://YOUR_INSTANCE.powersync.journeyapps.com
# or -d ios
```

## Preview URL (web — online-only)

https://infra-powersync-cloud-bootstrap.peeke-cmms-erp.pages.dev
