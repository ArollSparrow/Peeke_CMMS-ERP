/// PowerSync Cloud endpoint (SaaS).
///
/// Leave empty to keep the app online-only (Supabase). Set at build/run:
/// ```
/// flutter run --dart-define=POWERSYNC_URL=https://….powersync.journeyapps.com
/// ```
class PowerSyncEnv {
  PowerSyncEnv._();

  static const String url = String.fromEnvironment(
    'POWERSYNC_URL',
    defaultValue: '',
  );

  /// When false/empty URL, sync stack stays dormant — no local DB connect.
  static bool get isConfigured => url.trim().isNotEmpty;
}
