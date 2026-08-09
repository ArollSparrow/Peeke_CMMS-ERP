import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Emits auth state changes (sign-in / sign-out).
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  return auth?.session?.user ??
      ref.watch(supabaseClientProvider).auth.currentUser;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// True when Supabase has confirmed the user's email (ownership proof).
final isEmailConfirmedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return user.emailConfirmedAt != null;
});

/// Set when user opens a password-recovery email link.
/// Router forces `/reset-password` until password is updated or user signs out.
final passwordRecoveryPendingProvider = StateProvider<bool>((ref) {
  // Seed from URL on first load (web recovery links land with type=recovery).
  if (kIsWeb && uriIndicatesPasswordRecovery(Uri.base)) {
    return true;
  }
  return false;
});

/// True if the current browser URL is a Supabase password-recovery callback.
bool uriIndicatesPasswordRecovery(Uri uri) {
  final qp = uri.queryParameters['type'];
  if (qp == 'recovery') return true;

  // Hash fragment: #access_token=...&type=recovery
  final frag = uri.fragment;
  if (frag.isEmpty) return false;
  try {
    final params = Uri.splitQueryString(frag);
    if (params['type'] == 'recovery') return true;
  } catch (_) {}
  // Some clients use path-style or nested query in fragment
  if (frag.contains('type=recovery')) return true;
  return false;
}
