import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design/gloss_theme.dart';
import 'auth_providers.dart';

/// Opened from the Supabase recovery email link (`/reset-password`).
/// Works for platform owner and tenant accounts.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You are signed in.')),
      );
      context.go('/gate');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email;

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
                    'Set a new password',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: GlossColors.ink,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email != null
                        ? 'Account · $email'
                        : 'Open this page from the reset link in your email.',
                    style: const TextStyle(color: GlossColors.muted),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _password,
                    obscureText: !_show,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _show ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: !_show,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration:
                        const InputDecoration(labelText: 'Confirm new password'),
                    onSubmitted: (_) {
                      if (!_busy) _save();
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: GlossColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update password'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await ref.read(supabaseClientProvider).auth.signOut();
                            if (context.mounted) context.go('/login');
                          },
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
