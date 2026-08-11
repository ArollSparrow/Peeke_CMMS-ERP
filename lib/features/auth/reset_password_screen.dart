import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import 'auth_providers.dart';

/// Opened from the Supabase recovery email link (`/reset-password`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
          'Reset session expired or missing. Request a new link from Sign in → Forgot password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.updateUser(
            UserAttributes(password: _password.text),
          );
      ref.read(passwordRecoveryPendingProvider.notifier).state = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GlossColors.navy,
          content: Text(
            'Password updated. You are signed in.',
            style: TextStyle(color: GlossColors.sky),
          ),
        ),
      );
      context.go('/gate');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _fieldDecoration(String label) {
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
    final email = ref.watch(currentUserProvider)?.email;

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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/branding/peeke_icon.png',
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Text(
                          'Peeke',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: GlossColors.navy,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Peeke Automation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GlossColors.teal,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Set a new password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: GlossColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email != null
                        ? 'Account · $email'
                        : 'Open this page from the reset link in your email.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: GlossColors.teal,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _password,
                    obscureText: !_show,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: _fieldDecoration('New password').copyWith(
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
                    obscureText: !_show,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: _fieldDecoration('Confirm new password'),
                    onSubmitted: (_) {
                      if (!_busy) _save();
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: GlossColors.navy),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _save,
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
                        : const Text('Update password'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            ref
                                .read(passwordRecoveryPendingProvider.notifier)
                                .state = false;
                            await ref
                                .read(supabaseClientProvider)
                                .auth
                                .signOut();
                            if (context.mounted) context.go('/login');
                          },
                    style: TextButton.styleFrom(
                        foregroundColor: GlossColors.teal),
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
