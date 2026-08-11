import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import 'org_providers.dart';

class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  String _slugify(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('duplicate') || s.contains('unique')) {
      return 'That organization slug is already taken. Choose another.';
    }
    if (s.contains('JWT') || s.contains('session')) {
      return 'Your session expired. Sign in again, then create the organization.';
    }
    if (s.contains('not authenticated') || s.contains('Must be signed in')) {
      return 'Sign in first, then create your organization.';
    }
    if (s.length > 160) return 'Could not create the organization. Try again.';
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _submit() async {
    final confirmed = ref.read(isEmailConfirmedProvider);
    if (!confirmed) {
      setState(() => _error =
          'Confirm your email first (open the link we sent), then create the organization.');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter an organization name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final slug =
          _slug.text.trim().isEmpty ? _slugify(name) : _slug.text.trim();
      final org = await ref.read(orgRepositoryProvider).createOrganization(
            name: name,
            slug: slug,
          );
      ref.read(activeOrganizationIdProvider.notifier).state = org.id;
      ref.invalidate(myOrganizationsProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final email = ref.read(currentUserProvider)?.email;
    if (email == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.resend(
            type: OtpType.signup,
            email: email,
          );
      setState(() =>
          _info = 'Confirmation email resent to $email. Check inbox and spam.');
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(String label, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperStyle: const TextStyle(color: GlossColors.teal, fontSize: 11),
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: GlossColors.teal.withOpacity(0.4)),
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
    final confirmed = ref.watch(isEmailConfirmedProvider);

    return Scaffold(
      backgroundColor: GlossColors.sky,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/branding/peeke_icon.png',
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Text(
                          'Peeke',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: GlossColors.navy,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Peeke Automation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GlossColors.teal,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create your organization',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GlossColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your organization is the boundary for data, users, and billing. '
                    'Ownership is proven by the confirmed email on this account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GlossColors.teal, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GlossColors.teal),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          confirmed
                              ? Icons.mark_email_read
                              : Icons.mark_email_unread_outlined,
                          color: GlossColors.navy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.email ?? 'No email',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: GlossColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                confirmed
                                    ? 'Email confirmed — you can create an organization'
                                    : 'Open the confirmation link we sent, then continue',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: GlossColors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!confirmed)
                          TextButton(
                            onPressed: _busy ? null : _resend,
                            child: const Text('Resend'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    enabled: confirmed && !_busy,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    decoration: _field('Organization name'),
                    onChanged: (v) {
                      if (_slug.text.isEmpty ||
                          _slug.text == _slugify(_name.text)) {
                        _slug.text = _slugify(v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _slug,
                    enabled: confirmed && !_busy,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    decoration: _field(
                      'Slug',
                      helper: 'Unique URL-safe id, e.g. acme-facilities',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: GlossColors.navy),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _info!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: GlossColors.teal),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: (_busy || !confirmed) ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: GlossColors.navy,
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
                        : const Text('Create organization'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await ref
                                .read(supabaseClientProvider)
                                .auth
                                .signOut();
                            if (context.mounted) context.go('/login');
                          },
                    style: TextButton.styleFrom(
                        foregroundColor: GlossColors.teal),
                    child: const Text('Sign out'),
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
