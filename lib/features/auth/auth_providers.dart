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

/// True for team Auth invites (`type=invite`) and shareable links that land
/// on `/accept-invite` with `type=magiclink` (existing accounts via WhatsApp).
final invitePasswordPendingProvider = StateProvider<bool>((ref) {
  if (kIsWeb && uriIndicatesInvite(Uri.base)) return true;
  return false;
});

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

/// Team member invite link detection.
/// - Email invite: `type=invite`
/// - WhatsApp/SMS share for existing Auth users: often `type=magiclink`
///   with redirect path `/accept-invite`
bool uriIndicatesInvite(Uri uri) {
  final path = uri.path;
  final onAcceptPath = path == '/accept-invite' || path.endsWith('/accept-invite');

  String? typeFrom(Uri u) {
    final qp = u.queryParameters['type'];
    if (qp != null && qp.isNotEmpty) return qp;
    final frag = u.fragment;
    if (frag.isEmpty) return null;
    try {
      final params = Uri.splitQueryString(frag);
      return params['type'];
    } catch (_) {
      final m = RegExp(r'(?:^|&)type=([^&]*)').firstMatch(frag);
      return m?.group(1);
    }
  }

  final t = typeFrom(uri);
  if (t == 'invite') return true;
  // Shared action links for already-confirmed emails use magiclink → accept-invite
  if (t == 'magiclink' && onAcceptPath) return true;
  return false;
}

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
