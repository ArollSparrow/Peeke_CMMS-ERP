/// Clean-slate project: Peeke CMMS-ERP (`tappfahlaiixctyliesz`).
///
/// Override at build/run:
/// ```
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// ```
class SupabaseEnv {
  SupabaseEnv._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tappfahlaiixctyliesz.supabase.co',
  );

  /// Legacy anon JWT (publishable). Safe for client; never put service role here.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRhcHBmYWhsYWlpeGN0eWxpZXN6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1NzY5NTYsImV4cCI6MjEwMTE1Mjk1Nn0.Z-QK46G21yBuOy0Y3QcNAP_gMfmr_Jo1pRZ1ZKwRvV4',
  );
}
