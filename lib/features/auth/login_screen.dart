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

/// Matches logo wordmark feel: medium weight, tight tracking (not heavy bold).
const _logoMark = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: GlossColors.navy,
  letterSpacing: -0.2,
  height: 1.2,
);

/// Logo “CMMS-ERP” / node accent feel.
const _logoAccent = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: GlossColors.teal,
  letterSpacing: 0.3,
  height: 1.2,
);

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

  bool _offerForgotPassword = false;
  bool _offerResendConfirmation = false;

  static const double _fieldRadius = 28;
  static const double _formWidth = 300;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && uriIndicatesInvite(Uri.base)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(teamInviteLandingProvider.notifier).state = true;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    final inviteOnly = ref.read(teamInviteLandingProvider);
    if (inviteOnly && mode == _AuthMode.register) {
      setState(() {
        _error =
            'You were invited to join a team. Use Join your team from the '
            'invite link — do not create an organisation on this path.';
      });
      return;
    }
    setState(() {
      _mode = mode;
      _error = null;
      _info = null;
      if (mode != _AuthMode.register) {
        _confirm.clear();
      }
      if (mode == _AuthMode.forgot) {
        _offerForgotPassword = true;
      }
    });
  }

  void _classifySignInError(Object e) {
    final s = e.toString().toLowerCase();
    final msg = friendlyError(e);

    if (s.contains('invalid login') ||
        s.contains('invalid_credentials') ||
        msg.contains('incorrect')) {
      _offerForgotPassword = true;
    }

    if (s.contains('email not confirmed') ||
        s.contains('not confirmed') ||
        msg.toLowerCase().contains('confirm your email')) {
      _offerResendConfirmation = true;
    }

    _error = msg;
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
                'Open it from that inbox to set a new password.';
            _mode = _AuthMode.signIn;
            _offerForgotPassword = false;
          });
          break;

        case _AuthMode.register:
          if (ref.read(teamInviteLandingProvider)) {
            setState(() => _error =
                'Team invites use the Join your team screen. Do not create an organisation here.');
            break;
          }
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
                  'Check your inbox at $email and open the confirmation link. '
                  'Then sign in and create your organisation.';
              _mode = _AuthMode.signIn;
              _password.clear();
              _confirm.clear();
              _offerResendConfirmation = true;
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
      setState(() {
        if (_mode == _AuthMode.signIn) {
          _classifySignInError(e);
        } else {
          _error = friendlyError(e);
        }
      });
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
      setState(() {
        _info = 'Confirmation email resent to $email. Check inbox and spam.';
        _offerResendConfirmation = false;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _primaryLabel {
    switch (_mode) {
      case _AuthMode.register:
        return 'Create account';
      case _AuthMode.forgot:
        return 'Send reset link';
      case _AuthMode.signIn:
        return 'Sign in';
    }
  }

  InputDecoration _fieldDecoration(String label) {
    final radius = BorderRadius.circular(_fieldRadius);
    return InputDecoration(
      labelText: label,
      labelStyle: _logoMark.copyWith(fontSize: 14),
      floatingLabelStyle: _logoAccent.copyWith(fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide:
            BorderSide(color: GlossColors.teal.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: GlossColors.navy, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: GlossColors.teal),
      ),
    );
  }

  Widget _primaryAction() {
    final child = _busy
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _mode == _AuthMode.signIn
                  ? GlossColors.sky
                  : GlossColors.sky,
            ),
          )
        : Text(
            _primaryLabel,
            style: _logoMark.copyWith(
              color: GlossColors.sky,
              fontSize: 15,
            ),
          );

    // Sign in only: compact pill sized to the label, teal (logo accent)
    if (_mode == _AuthMode.signIn) {
      return Center(
        child: FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: GlossColors.teal,
            foregroundColor: GlossColors.sky,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_fieldRadius),
            ),
          ),
          child: child,
        ),
      );
    }

    // Register / forgot: full-width form action
    return FilledButton(
      onPressed: _busy ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: GlossColors.navy,
        foregroundColor: GlossColors.sky,
        minimumSize: const Size.fromHeight(46),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inviteOnly = ref.watch(teamInviteLandingProvider);

    ref.listen(authStateProvider, (prev, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery && context.mounted) {
        context.go('/reset-password');
      }
      final user = next.valueOrNull?.session?.user;
      if (user != null) {
        final meta = user.userMetadata;
        if (meta != null &&
            (meta['invited_organization_id'] != null ||
                meta['invited_at'] != null)) {
          ref.read(teamInviteLandingProvider.notifier).state = true;
        }
      }
    });

    return Scaffold(
      backgroundColor: GlossColors.sky,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _formWidth),
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
                              style: _logoMark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_mode == _AuthMode.register) ...[
                          const Text(
                            'Create organisation',
                            textAlign: TextAlign.center,
                            style: _logoMark,
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (_mode == _AuthMode.forgot) ...[
                          const Text(
                            'Reset password',
                            textAlign: TextAlign.center,
                            style: _logoMark,
                          ),
                          const SizedBox(height: 18),
                        ],

                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: _logoMark.copyWith(fontSize: 14),
                          cursorColor: GlossColors.navy,
                          autofillHints: const [AutofillHints.email],
                          decoration: _fieldDecoration('Email'),
                        ),
                        if (_mode != _AuthMode.forgot) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: !_showPassword,
                            style: _logoMark.copyWith(fontSize: 14),
                            cursorColor: GlossColors.navy,
                            autofillHints: _mode == _AuthMode.register
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            decoration: _fieldDecoration('Password').copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color:
                                      GlossColors.navy.withValues(alpha: 0.7),
                                  size: 20,
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
                            style: _logoMark.copyWith(fontSize: 14),
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
                            style: const TextStyle(
                              color: GlossColors.danger,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (_info != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _info!,
                            textAlign: TextAlign.center,
                            style: _logoAccent,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _primaryAction(),
                        if (_mode == _AuthMode.signIn) ...[
                          if (_offerForgotPassword && !inviteOnly) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setMode(_AuthMode.forgot),
                              child: const Text(
                                'Forgot password?',
                                style: _logoAccent,
                              ),
                            ),
                          ],
                          if (_offerResendConfirmation && !inviteOnly) ...[
                            const SizedBox(height: 2),
                            TextButton(
                              onPressed:
                                  _busy ? null : _resendConfirmation,
                              child: const Text(
                                'Resend confirmation email',
                                style: _logoAccent,
                              ),
                            ),
                          ],
                          if (!inviteOnly) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _setMode(_AuthMode.register),
                                icon: const Icon(
                                  Icons.link,
                                  size: 18,
                                  color: GlossColors.navy,
                                ),
                                label: const Text(
                                  'Create Organisation',
                                  style: _logoMark,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: GlossColors.navy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (_mode == _AuthMode.register)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _setMode(_AuthMode.signIn),
                            child: const Text(
                              'Already have an account? Sign in',
                              style: _logoAccent,
                            ),
                          ),
                        if (_mode == _AuthMode.forgot)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _setMode(_AuthMode.signIn),
                            child: const Text(
                              'Back to sign in',
                              style: _logoAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16, top: 8),
              child: Text(
                '© Peeke Automation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: GlossColors.navy,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
