import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final client = ref.read(supabaseClientProvider);
    try {
      if (_register) {
        final res = await client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        // When confirm-email is enabled, session may be null until link is clicked.
        if (res.session == null) {
          setState(() {
            _info =
                'Check your inbox at ${_email.text.trim()} and open the confirmation link to prove ownership. Then sign in and create your organization.';
            _register = false;
          });
        }
      } else {
        await client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
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
          );
      setState(() =>
          _info = 'Confirmation email resent to $email. Check inbox and spam.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Peeke CMMS-ERP',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: GlossColors.ink,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _register
                        ? 'Register as a tenant (new email)'
                        : 'Sign in to continue',
                    style: const TextStyle(color: GlossColors.muted),
                  ),
                  const SizedBox(height: 8),
                  if (_register)
                    const Text(
                      'Use a work email you control. We send a confirmation link — '
                      'you must open it before creating an organization (proves ownership).',
                      style: TextStyle(color: GlossColors.muted, fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: GlossColors.danger)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 12),
                    Text(_info!, style: const TextStyle(color: Color(0xFF16A34A))),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_register ? 'Register tenant account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _register = !_register;
                              _error = null;
                              _info = null;
                            }),
                    child: Text(
                      _register
                          ? 'Already have an account? Sign in'
                          : 'Need a tenant account? Register',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _resendConfirmation,
                    child: const Text('Resend confirmation email'),
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
