import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create organization')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Your organization is the tenant boundary for data, users, and payments.',
            style: TextStyle(color: GlossColors.muted),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
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
            onPressed: _busy ? null : _submit,
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
