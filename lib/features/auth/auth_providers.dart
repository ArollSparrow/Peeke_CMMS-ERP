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
final passwordRecoveryPendingProvider = StateProvider<bool>((ref) {
  if (kIsWeb && uriIndicatesPasswordRecovery(Uri.base)) {
    return true;
  }
  return false;
});

/// Sticky flag: user arrived via team invite (URL or session metadata).
/// Hides "Register as a tenant" so invitees do not self-serve a new org.
final teamInviteLandingProvider = StateProvider<bool>((ref) {
  if (kIsWeb && uriIndicatesInvite(Uri.base)) return true;
  return false;
});

/// True if signed-in user was created via Auth invite (metadata).
final isInvitedUserProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final meta = user.userMetadata;
  if (meta == null) return false;
  if (meta['invited_organization_id'] != null) return true;
  // Supabase may set invited_at on invite flow
  if (meta['invited_at'] != null) return true;
  return false;
});

/// Pending org invites for current user email (SECURITY DEFINER count).
final myPendingInviteCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  try {
    final n =
        await ref.read(supabaseClientProvider).rpc('my_pending_invite_count');
    if (n is int) return n;
    if (n is num) return n.toInt();
    return int.tryParse('$n') ?? 0;
  } catch (_) {
    return 0;
  }
});

bool uriIndicatesPasswordRecovery(Uri uri) {
  final qp = uri.queryParameters['type'];
  if (qp == 'recovery') return true;

  final frag = uri.fragment;
  if (frag.isEmpty) return false;
  try {
    final params = Uri.splitQueryString(frag);
    if (params['type'] == 'recovery') return true;
  } catch (_) {}
  if (frag.contains('type=recovery')) return true;
  return false;
}

/// Invite callback from Supabase Auth email link.
bool uriIndicatesInvite(Uri uri) {
  final qp = uri.queryParameters['type'];
  if (qp == 'invite') return true;

  final frag = uri.fragment;
  if (frag.isEmpty) return false;
  try {
    final params = Uri.splitQueryString(frag);
    if (params['type'] == 'invite') return true;
  } catch (_) {}
  if (frag.contains('type=invite')) return true;
  return false;
}
