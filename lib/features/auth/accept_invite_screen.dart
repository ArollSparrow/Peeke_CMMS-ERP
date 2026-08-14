import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import 'auth_providers.dart';

/// Dedicated path for **team invitees** only (`type=invite` email link).
/// Tenant signup / Create Organisation must never land here.
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
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
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
          'Invite session not active. Open the latest “Accept invitation” link '
          'from your email (links expire). Do not use Create Organisation.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final client = ref.read(supabaseClientProvider);
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

      // Best-effort: sync details via self-service RPC if available
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
      } catch (_) {
        // Name/phone already on membership via accept_pending_org_invites
      }

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
                            'This is not organisation registration.'
                        : 'Waiting for invite session…\n'
                            'Open the full Accept invitation link from the '
                            'email (or the shared action link). '
                            'Expired links will not activate this form.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: GlossColors.teal,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (!sessionReady) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'If you intended to create your own organisation, '
                      'use Sign in → Create Organisation instead.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GlossColors.navy,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: _fullName,
                    enabled: sessionReady && !_busy,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.name],
                    decoration: _field('Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    enabled: sessionReady && !_busy,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: _field('Phone (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: sessionReady && !_busy,
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
                    enabled: sessionReady && !_busy,
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
                    onPressed: (_busy || !sessionReady) ? null : _complete,
                    style: FilledButton.styleFrom(
                      backgroundColor: GlossColors.teal,
                      foregroundColor: GlossColors.sky,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
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
                                : 'Link not active yet',
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
