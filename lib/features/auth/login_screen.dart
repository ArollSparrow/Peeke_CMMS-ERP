import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import 'auth_providers.dart';

enum _AuthMode { signIn, register, forgot }

String authRedirectTo(String path) {
  if (kIsWeb) {
    return '${Uri.base.origin}$path';
  }
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
      setState(() => _error = friendlyError(e));
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
      setState(() => _error = friendlyError(e));
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

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: GlossColors.navy),
      floatingLabelStyle: const TextStyle(color: GlossColors.teal),
      filled: true,
      fillColor: GlossColors.sky,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GlossColors.teal, width: 1),
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
                        height: 140,
                        width: 140,
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
                  Text(
                    _title,
                    textAlign: TextAlign.center,
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GlossColors.teal,
                        fontSize: 12,
                      ),
                    ),
                  if (_mode == _AuthMode.forgot)
                    const Text(
                      'Enter the email for your account. We will send a one-time '
                      'link so you can choose a new password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GlossColors.teal,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: GlossColors.navy),
                    cursorColor: GlossColors.navy,
                    autofillHints: const [AutofillHints.email],
                    decoration: _fieldDecoration('Email'),
                  ),
                  if (_mode != _AuthMode.forgot) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      style: const TextStyle(color: GlossColors.navy),
                      cursorColor: GlossColors.navy,
                      autofillHints: _mode == _AuthMode.register
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: _fieldDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: GlossColors.navy,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                  ],
                  if (_mode == _AuthMode.register) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: !_showPassword,
                      style: const TextStyle(color: GlossColors.navy),
                      cursorColor: GlossColors.navy,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _fieldDecoration('Confirm password'),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                  ],
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
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
                        : Text(_primaryLabel),
                  ),
                  if (_mode == _AuthMode.signIn) ...[
                    TextButton(
                      onPressed:
                          _busy ? null : () => _setMode(_AuthMode.forgot),
                      style: TextButton.styleFrom(
                          foregroundColor: GlossColors.teal),
                      child: const Text('Forgot password?'),
                    ),
                    TextButton(
                      onPressed:
                          _busy ? null : () => _setMode(_AuthMode.register),
                      style: TextButton.styleFrom(
                          foregroundColor: GlossColors.navy),
                      child: const Text('Need a tenant account? Register'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _resendConfirmation,
                      style: TextButton.styleFrom(
                          foregroundColor: GlossColors.teal),
                      child: const Text('Resend confirmation email'),
                    ),
                  ],
                  if (_mode == _AuthMode.register)
                    TextButton(
                      onPressed:
                          _busy ? null : () => _setMode(_AuthMode.signIn),
                      style: TextButton.styleFrom(
                          foregroundColor: GlossColors.navy),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  if (_mode == _AuthMode.forgot)
                    TextButton(
                      onPressed:
                          _busy ? null : () => _setMode(_AuthMode.signIn),
                      style: TextButton.styleFrom(
                          foregroundColor: GlossColors.navy),
                      child: const Text('Back to sign in'),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    '© Peeke Automation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: GlossColors.navy,
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
