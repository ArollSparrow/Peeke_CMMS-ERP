import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

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

final isEmailConfirmedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return user.emailConfirmedAt != null;
});

final passwordRecoveryPendingProvider = StateProvider<bool>((ref) {
  if (kIsWeb && uriIndicatesPasswordRecovery(Uri.base)) {
    return true;
  }
  return false;
});

/// True only for **team Auth invites** (`type=invite` in the email link).
/// Never true for tenant signup / email confirm (`type=signup` / `email`).
final invitePasswordPendingProvider = StateProvider<bool>((ref) {
  if (kIsWeb && uriIndicatesInvite(Uri.base)) return true;
  return false;
});

/// Soft flag for UI copy (hide Create Organisation on login).
final teamInviteLandingProvider = StateProvider<bool>((ref) {
  if (kIsWeb && uriIndicatesInvite(Uri.base)) return true;
  return false;
});

final isInvitedUserProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final meta = user.userMetadata;
  if (meta == null) return false;
  if (meta['invited_organization_id'] != null) return true;
  if (meta['invited_at'] != null) return true;
  return false;
});

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

/// Team member invite only — requires Auth `type=invite`.
/// Path `/accept-invite` alone is **not** enough (avoids trapping tenant signup).
bool uriIndicatesInvite(Uri uri) {
  final qp = uri.queryParameters['type'];
  if (qp == 'invite') return true;

  final frag = uri.fragment;
  if (frag.isNotEmpty) {
    try {
      final params = Uri.splitQueryString(frag);
      if (params['type'] == 'invite') return true;
    } catch (_) {}
    // Prefer exact query segment so we never match unrelated fragments
    if (RegExp(r'(^|&)type=invite(&|$)').hasMatch(frag)) return true;
  }
  return false;
}

/// Signup / email confirmation — tenant path, not team join.
bool uriIndicatesSignupConfirm(Uri uri) {
  final qp = uri.queryParameters['type'];
  if (qp == 'signup' || qp == 'email') return true;
  final frag = uri.fragment;
  if (frag.isEmpty) return false;
  try {
    final params = Uri.splitQueryString(frag);
    final t = params['type'];
    if (t == 'signup' || t == 'email') return true;
  } catch (_) {}
  return false;
}
