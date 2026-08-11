# Peeke branding

## Official launcher icon (locked 2026-08-11)

- **Mark:** Peeke wordmark + teal network on the *e* + `CMMS-ERP` subtitle
- **Background:** light sky blue `#E8F4FC`
- **Primary text:** deep navy `#0B1F3A`
- **Accent:** soft teal `#2A9D8F`

### File required

Place the approved square icon here:

```text
assets/branding/peeke_icon.png
```

Recommended: **1024×1024** PNG (or at least 512×512), sky-blue background, logo centered with padding.

### Generate platform icons

```bash
flutter pub get
dart run flutter_launcher_icons
```

Then rebuild the Android APK (Actions → **Build Android APK** or local `flutter build apk`).
