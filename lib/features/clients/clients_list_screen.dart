import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../org/org_providers.dart';
import 'client_providers.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreate() async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;

    _nameCtrl.clear();
    _codeCtrl.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code (optional)',
                hintText: 'e.g. ACME',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(clientRepositoryProvider).create(
            organizationId: org.id,
            name: name,
            code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text,
          );
      ref.invalidate(clientsListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientsListProvider);
    final org = ref.watch(activeOrganizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          if (org != null)
            IconButton(
              tooltip: 'Add client',
              onPressed: _saving ? null : _showCreate,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: org == null
          ? const Center(child: Text('Select an organization first'))
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No clients yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Clients own sites and systems in this tenant.',
                          style: TextStyle(color: GlossColors.muted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _showCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Add client'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return Card(
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          [
                            if (c.code != null && c.code!.isNotEmpty) c.code,
                            if (c.contactName != null) c.contactName,
                          ].whereType<String>().join(' · '),
                          style: const TextStyle(color: GlossColors.muted),
                        ),
                        trailing: c.isActive
                            ? null
                            : const Chip(label: Text('Inactive')),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
