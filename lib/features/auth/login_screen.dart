import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import 'auth_providers.dart';

enum _AuthMode { signIn, register, forgot }

/// Redirect target for recovery / confirm links (must be allow-listed in Supabase).
String authRedirectTo(String path) {
  if (kIsWeb) {
    return '${Uri.base.origin}$path';
  }
  // Mobile / desktop: point at production web until deep links are configured.
  return 'https://peeke-cmms-erp.pages.dev$path';
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _info = null;
      if (mode != _AuthMode.register) {
        _confirm.clear();
      }
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final client = ref.read(supabaseClientProvider);

    try {
      switch (_mode) {
        case _AuthMode.forgot:
          await client.auth.resetPasswordForEmail(
            email,
            redirectTo: authRedirectTo('/reset-password'),
          );
          setState(() {
            _info =
                'If an account exists for $email, a reset link was sent. '
                'Open it from that inbox to set a new password. '
                'Check spam if you do not see it within a few minutes.';
            _mode = _AuthMode.signIn;
          });
          break;

        case _AuthMode.register:
          if (_password.text.length < 8) {
            setState(() => _error = 'Password must be at least 8 characters');
            break;
          }
          if (_password.text != _confirm.text) {
            setState(() => _error = 'Password and confirmation do not match');
            break;
          }
          final res = await client.auth.signUp(
            email: email,
            password: _password.text,
            emailRedirectTo: authRedirectTo('/gate'),
          );
          if (res.session == null) {
            setState(() {
              _info =
                  'Check your inbox at $email and open the confirmation link '
                  'to prove ownership. Then sign in and create your organization.';
              _mode = _AuthMode.signIn;
              _password.clear();
              _confirm.clear();
            });
          }
          break;

        case _AuthMode.signIn:
          if (_password.text.isEmpty) {
            setState(() => _error = 'Enter your password');
            break;
          }
          await client.auth.signInWithPassword(
            email: email,
            password: _password.text,
          );
          break;
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.resend(
            type: OtpType.signup,
            email: email,
            emailRedirectTo: authRedirectTo('/gate'),
          );
      setState(() =>
          _info = 'Confirmation email resent to $email. Check inbox and spam.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title {
    switch (_mode) {
      case _AuthMode.register:
        return 'Register as a tenant';
      case _AuthMode.forgot:
        return 'Reset your password';
      case _AuthMode.signIn:
        return 'Sign in to continue';
    }
  }

  String get _primaryLabel {
    switch (_mode) {
      case _AuthMode.register:
        return 'Register tenant account';
      case _AuthMode.forgot:
        return 'Send reset link';
      case _AuthMode.signIn:
        return 'Sign in';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery && context.mounted) {
        context.go('/reset-password');
      }
    });

    return Scaffold(
      backgroundColor: GlossColors.sky,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand header
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/branding/peeke_icon.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        width: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GlossColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: GlossColors.border),
                        ),
                        child: const Text(
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
                  const SizedBox(height: 16),
                  const Text(
                    'Peeke CMMS-ERP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: GlossColors.navy,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Multi-tenant maintenance & operations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: GlossColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'by Peeke Automation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GlossColors.teal.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Auth card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: GlossColors.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_mode == _AuthMode.register)
                            const Text(
                              'Use a work email you control. We send a confirmation link — '
                              'you must open it before creating an organization.',
                              style: TextStyle(
                                color: GlossColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          if (_mode == _AuthMode.forgot)
                            const Text(
                              'Enter the email for your account. We will send a one-time '
                              'link so you can choose a new password.',
                              style: TextStyle(
                                color: GlossColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          if (_mode != _AuthMode.forgot) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: !_showPassword,
                              autofillHints: _mode == _AuthMode.register
                                  ? const [AutofillHints.newPassword]
                                  : const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: GlossColors.muted,
                                  ),
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                          ],
                          if (_mode == _AuthMode.register) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirm,
                              obscureText: !_showPassword,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                              ),
                              onSubmitted: (_) => _busy ? null : _submit(),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: GlossColors.danger),
                            ),
                          ],
                          if (_info != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _info!,
                              style:
                                  const TextStyle(color: GlossColors.success),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_primaryLabel),
                          ),
                          if (_mode == _AuthMode.signIn) ...[
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setMode(_AuthMode.forgot),
                              child: const Text('Forgot password?'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setMode(_AuthMode.register),
                              child: const Text(
                                  'Need a tenant account? Register'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _resendConfirmation,
                              child: const Text('Resend confirmation email'),
                            ),
                          ],
                          if (_mode == _AuthMode.register)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setMode(_AuthMode.signIn),
                              child: const Text(
                                  'Already have an account? Sign in'),
                            ),
                          if (_mode == _AuthMode.forgot)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setMode(_AuthMode.signIn),
                              child: const Text('Back to sign in'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    '© Peeke Automation · Peeke CMMS-ERP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: GlossColors.muted,
                    ),
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
