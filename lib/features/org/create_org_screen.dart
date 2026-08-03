import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> _submit() async {
    final confirmed = ref.read(isEmailConfirmedProvider);
    if (!confirmed) {
      setState(() => _error =
          'Confirm your email first (check inbox for the verification link), then create the organization.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final slug =
          _slug.text.trim().isEmpty ? _slugify(_name.text) : _slug.text.trim();
      final org = await ref.read(orgRepositoryProvider).createOrganization(
            name: _name.text.trim(),
            slug: slug,
          );
      ref.read(activeOrganizationIdProvider.notifier).state = org.id;
      ref.invalidate(myOrganizationsProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString());
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
    });
    try {
      await ref.read(supabaseClientProvider).auth.resend(
            type: OtpType.signup,
            email: email,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirmation resent to $email')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final confirmed = ref.watch(isEmailConfirmedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create organization')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Your organization is the tenant boundary for data, users, and payments. '
            'Ownership is proven by the confirmed email on this account.',
            style: TextStyle(color: GlossColors.muted),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                confirmed ? Icons.mark_email_read : Icons.mark_email_unread_outlined,
                color: confirmed ? const Color(0xFF16A34A) : GlossColors.muted,
              ),
              title: Text(user?.email ?? 'No email'),
              subtitle: Text(
                confirmed
                    ? 'Email confirmed — you can create an organization'
                    : 'Email not confirmed yet — open the link we sent, then continue',
              ),
              trailing: confirmed
                  ? null
                  : TextButton(
                      onPressed: _busy ? null : _resend,
                      child: const Text('Resend'),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            enabled: confirmed,
            decoration: const InputDecoration(labelText: 'Organization name'),
            onChanged: (v) {
              if (_slug.text.isEmpty || _slug.text == _slugify(_name.text)) {
                _slug.text = _slugify(v);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slug,
            enabled: confirmed,
            decoration: const InputDecoration(
              labelText: 'Slug',
              helperText: 'Unique URL-safe id, e.g. acme-facilities',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: GlossColors.danger)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_busy || !confirmed) ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create organization'),
          ),
        ],
      ),
    );
  }
}
