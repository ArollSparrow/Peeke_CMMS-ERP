import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import 'auth_providers.dart';

/// Dedicated path for **team invitees** only.
/// Tenant signup / Create Organisation must never land here.
///
/// Primary activation path: **email invite link**.
/// Admin WhatsApp/SMS action_link is fallback when mail cannot deliver.
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key});

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _show = false;
  bool _recovering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recoverInviteSessionFromUrl();
      });
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _markInviteSession() {
    ref.read(invitePasswordPendingProvider.notifier).state = true;
    ref.read(teamInviteLandingProvider.notifier).state = true;
  }

  /// Recover session from whatever the email (or admin action_link) put in the URL:
  /// - PKCE: ?code=
  /// - Implicit: #access_token=…&type=invite
  /// - token_hash: ?token_hash=…&type=invite (custom templates)
  Future<void> _recoverInviteSessionFromUrl() async {
    if (!kIsWeb) return;
    final client = ref.read(supabaseClientProvider);
    if (client.auth.currentUser != null) {
      _markInviteSession();
      return;
    }

    final uri = Uri.base;
    final linkError = _authErrorFromUri(uri);
    if (linkError != null) {
      if (mounted) setState(() => _error = linkError);
      return;
    }

    if (mounted) {
      setState(() {
        _recovering = true;
        _error = null;
      });
    }

    try {
      // 1) token_hash + type (works even when ConfirmationURL was customized)
      final tokenHash = uri.queryParameters['token_hash'] ??
          _fragParam(uri, 'token_hash');
      final otpType = uri.queryParameters['type'] ?? _fragParam(uri, 'type');
      if (tokenHash != null &&
          tokenHash.isNotEmpty &&
          (otpType == 'invite' ||
              otpType == 'magiclink' ||
              otpType == 'email')) {
        final type = otpType == 'magiclink'
            ? OtpType.magiclink
            : otpType == 'email'
                ? OtpType.email
                : OtpType.invite;
        await client.auth.verifyOTP(
          tokenHash: tokenHash,
          type: type,
        );
        if (client.auth.currentUser != null) {
          _markInviteSession();
          return;
        }
      }

      // 2) PKCE auth code
      final code =
          uri.queryParameters['code'] ?? _fragParam(uri, 'code');
      if (code != null && code.isNotEmpty) {
        await client.auth.exchangeCodeForSession(code);
        if (client.auth.currentUser != null) {
          _markInviteSession();
          return;
        }
      }

      // 3) Implicit hash / query tokens
      if (_uriHasAuthTokens(uri) || uriIndicatesInvite(uri)) {
        try {
          await client.auth.getSessionFromUrl(uri);
        } catch (_) {
          // detectSessionInUri may already have consumed the fragment
        }
        if (client.auth.currentUser != null) {
          _markInviteSession();
          return;
        }
      }

      // 4) Brief wait for auto detectSessionInUri
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        if (client.auth.currentUser != null) {
          _markInviteSession();
          return;
        }
      }

      if (!mounted) return;
      final bare = !_uriHasAuthTokens(uri) &&
          (uri.queryParameters['code']?.isEmpty ?? true) &&
          (uri.queryParameters['token_hash']?.isEmpty ?? true) &&
          !_fragHasAuth(uri);
      setState(() {
        _error = bare
            ? 'This page has no invite session tokens. '
                'Usually that means the email link was already opened once '
                '(Gmail/Chrome preview can use up a one-time link), '
                'or the redirect lost the tokens.\n\n'
                'Ask the organisation admin to cancel and send a new invite, '
                'then open the new email link once in a private window '
                '(do not preview the link first).'
            : 'Could not activate this invite link. '
                'It may be expired or already used. '
                'Ask your organisation admin to send a fresh invite email.';
      });
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (mounted) {
        setState(() {
          if (msg.contains('expired') ||
              msg.contains('invalid') ||
              msg.contains('access_denied') ||
              msg.contains('otp')) {
            _error =
                'This invite link is invalid or has expired. '
                'Ask your organisation admin to send a fresh invite email, '
                'then open the new link once in a private window.';
          } else {
            _error = friendlyError(e);
          }
        });
      }
    } catch (e) {
      if (mounted && client.auth.currentUser == null) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  static String? _fragParam(Uri uri, String key) {
    final frag = uri.fragment;
    if (frag.isEmpty) return null;
    try {
      return Uri.splitQueryString(frag)[key];
    } catch (_) {
      return null;
    }
  }

  static bool _fragHasAuth(Uri uri) {
    final frag = uri.fragment;
    if (frag.isEmpty) return false;
    return frag.contains('access_token=') ||
        frag.contains('refresh_token=') ||
        frag.contains('type=invite');
  }

  static bool _uriHasAuthTokens(Uri uri) {
    bool hasIn(Map<String, String> m) =>
        (m['access_token']?.isNotEmpty ?? false) ||
        (m['refresh_token']?.isNotEmpty ?? false);

    if (hasIn(uri.queryParameters)) return true;
    final frag = uri.fragment;
    if (frag.isEmpty) return false;
    try {
      return hasIn(Uri.splitQueryString(frag));
    } catch (_) {
      return frag.contains('access_token=');
    }
  }

  static String? _authErrorFromUri(Uri uri) {
    String? pick(Map<String, String> m) {
      final desc = m['error_description'] ?? m['error'];
      if (desc == null || desc.isEmpty) return null;
      final decoded = Uri.decodeComponent(desc.replaceAll('+', ' '));
      final lower = decoded.toLowerCase();
      if (lower.contains('expired') || lower.contains('invalid')) {
        return 'This invite link is invalid or has expired. '
            'Ask your organisation admin to send a fresh invite email, '
            'then open the new link once in a private window.';
      }
      return decoded;
    }

    final fromQuery = pick(uri.queryParameters);
    if (fromQuery != null) return fromQuery;
    final frag = uri.fragment;
    if (frag.isEmpty) return null;
    try {
      return pick(Uri.splitQueryString(frag));
    } catch (_) {
      return null;
    }
  }

  Future<bool> _sessionIsInvitee(SupabaseClient client, User user) async {
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;
    try {
      final rows = await client
          .from('organization_invites')
          .select('id')
          .eq('email', email)
          .eq('status', 'pending')
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _complete() async {
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter your full name');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Password and confirmation do not match');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error =
          'Invite session not active. Open the latest Accept invitation link '
          'from your email while signed out (or in a private window).');
      return;
    }

    final client = ref.read(supabaseClientProvider);

    final okInvitee = await _sessionIsInvitee(client, user);
    if (!okInvitee) {
      setState(() => _error =
          'This session (${user.email}) has no pending team invite. '
          'Sign out completely, then open the invite link from your email '
          'in a private window so you join as the invited email — '
          'not as the organisation owner.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await client.auth.updateUser(
        UserAttributes(
          password: _password.text,
          data: {
            'full_name': name,
            'display_name': name,
            if (phone.isNotEmpty) 'phone': phone,
          },
        ),
      );

      try {
        await client.rpc('accept_pending_org_invites');
      } catch (_) {}

      try {
        final memberships = await client
            .from('organization_members')
            .select('organization_id')
            .eq('user_id', user.id);
        for (final row in (memberships as List)) {
          final orgId = (row as Map)['organization_id'] as String?;
          if (orgId == null) continue;
          await client.rpc(
            'update_my_org_profile',
            params: {
              'p_organization_id': orgId,
              'p_full_name': name,
              'p_phone': phone.isEmpty ? null : phone,
            },
          );
        }
      } catch (_) {}

      ref.read(invitePasswordPendingProvider.notifier).state = false;
      ref.read(teamInviteLandingProvider.notifier).state = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GlossColors.navy,
          content: Text(
            'Welcome — your team access is ready.',
            style: TextStyle(color: GlossColors.sky),
          ),
        ),
      );
      context.go('/gate');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: GlossColors.navy),
      floatingLabelStyle: const TextStyle(color: GlossColors.teal),
      filled: true,
      fillColor: GlossColors.sky,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GlossColors.teal),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GlossColors.navy, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GlossColors.teal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final email = user?.email;
    final sessionReady = user != null;
    final fieldsEnabled = sessionReady && !_busy && !_recovering;

    return Scaffold(
      backgroundColor: GlossColors.sky,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/branding/peeke_icon.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'Peeke',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: GlossColors.navy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Join your team',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: GlossColors.navy,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sessionReady
                        ? 'Invited as $email\n'
                            'Enter your details and create a password to become a member. '
                            'This is not organisation registration.\n'
                            'If this is not the invited email, sign out and open the link from your email in a private window.'
                        : _recovering
                            ? 'Activating your invite from email…'
                            : 'Open the Accept invitation link from your email '
                                'while signed out (or in a private window). '
                                'Expired or already-used links will not activate this form.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: GlossColors.teal,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _fullName,
                    enabled: fieldsEnabled,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.name],
                    decoration: _field('Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    enabled: fieldsEnabled,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: _field('Phone (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: fieldsEnabled,
                    obscureText: !_show,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: _field('Create password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _show ? Icons.visibility_off : Icons.visibility,
                          color: GlossColors.navy,
                        ),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    enabled: fieldsEnabled,
                    obscureText: !_show,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: _field('Confirm password'),
                    onSubmitted: (_) {
                      if (!_busy && sessionReady) _complete();
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: GlossColors.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: (_busy || !sessionReady || _recovering)
                        ? null
                        : _complete,
                    style: FilledButton.styleFrom(
                      backgroundColor: GlossColors.teal,
                      foregroundColor: GlossColors.sky,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy || _recovering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: GlossColors.sky,
                            ),
                          )
                        : Text(
                            sessionReady
                                ? 'Create password & join team'
                                : 'Waiting for email invite link',
                          ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            ref
                                .read(invitePasswordPendingProvider.notifier)
                                .state = false;
                            ref
                                .read(teamInviteLandingProvider.notifier)
                                .state = false;
                            await ref
                                .read(supabaseClientProvider)
                                .auth
                                .signOut();
                            if (context.mounted) context.go('/login');
                          },
                    style: TextButton.styleFrom(
                        foregroundColor: GlossColors.navy),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
