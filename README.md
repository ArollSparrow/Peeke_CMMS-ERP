# Peeke CMMS-ERP

**Peeke™**

Clean-slate multi-tenant CMMS-ERP (Flutter · Riverpod).

## Live

Web is published via Cloudflare Pages (`peeke-web`).

## Development

- Flutter stable
- Primary targets: Android + iOS (mobile-first)
- Web for office users

```bash
git clone https://github.com/ArollSparrow/Peeke_CMMS-ERP.git
cd Peeke_CMMS-ERP
git checkout redesign/gloss-restrained-full-depth
flutter pub get
flutter run
```

## Deploy

Cloudflare Pages builds from the production branch above.  
GitHub Actions workflow (`.github/workflows/deploy-cloudflare-pages.yml`) is available as a manual fallback.
