import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../org/org_providers.dart';
import 'client_models.dart';
import 'client_providers.dart';

class SystemsListScreen extends ConsumerStatefulWidget {
  const SystemsListScreen({super.key});

  @override
  ConsumerState<SystemsListScreen> createState() => _SystemsListScreenState();
}

class _SystemsListScreenState extends ConsumerState<SystemsListScreen> {
  bool _saving = false;

  static const _types = ['Generator', 'PV Inverter', 'Pump Inverter', 'Other'];
  static const _units = ['kW', 'kVA'];

  Future<void> _showCreate() async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;

    final clients = await ref.read(clientRepositoryProvider).list(
          organizationId: org.id,
        );
    if (!mounted) return;

    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a client first — systems must belong to a client.'),
        ),
      );
      return;
    }

    Client selectedClient = clients.first;
    String? selectedType = _types.first;
    String? selectedUnit = _units.first;
    final nameCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New system'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Client>(
                  value: selectedClient,
                  decoration: const InputDecoration(labelText: 'Client *'),
                  items: clients
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c.siteName != null && c.siteName!.isNotEmpty
                                ? '${c.name} · ${c.siteName}'
                                : c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (c) {
                    if (c != null) setLocal(() => selectedClient = c);
                  },
                ),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'System type *'),
                  items: _types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (t) => setLocal(() => selectedType = t),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display name *',
                    hintText: 'e.g. Gen-1 Main',
                  ),
                ),
                TextField(
                  controller: serialCtrl,
                  decoration: const InputDecoration(labelText: 'Serial number'),
                ),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: capacityCtrl,
                        decoration: const InputDecoration(labelText: 'Capacity'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _units
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (u) => setLocal(() => selectedUnit = u),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      ),
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      serialCtrl.dispose();
      modelCtrl.dispose();
      capacityCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim().isNotEmpty
        ? nameCtrl.text.trim()
        : [
            selectedType,
            serialCtrl.text.trim().isNotEmpty
                ? serialCtrl.text.trim()
                : modelCtrl.text.trim(),
          ].where((e) => e != null && e.isNotEmpty).join(' ');

    if (name.isEmpty) {
      nameCtrl.dispose();
      serialCtrl.dispose();
      modelCtrl.dispose();
      capacityCtrl.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name or serial/model is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(systemRepositoryProvider).create(
            organizationId: org.id,
            name: name,
            clientId: selectedClient.id,
            clientName: selectedClient.name,
            clientLocation: selectedClient.location,
            clientSite: selectedClient.siteName,
            type: selectedType,
            model: modelCtrl.text,
            serialNumber: serialCtrl.text,
            capacity: double.tryParse(capacityCtrl.text.trim()),
            capacityUnit: selectedUnit,
          );
      ref.invalidate(systemsListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      nameCtrl.dispose();
      serialCtrl.dispose();
      modelCtrl.dispose();
      capacityCtrl.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(systemsListProvider);
    final org = ref.watch(activeOrganizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Systems'),
        actions: [
          if (org != null)
            IconButton(
              tooltip: 'Add system',
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
                          'No systems yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Systems are assets linked to a client (generator, inverter, …).',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: GlossColors.muted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _showCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Add system'),
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
                    final s = items[i];
                    return Card(
                      child: ListTile(
                        title: Text(s.name),
                        subtitle: Text(
                          s.subtitle.isEmpty ? s.status : s.subtitle,
                          style: const TextStyle(color: GlossColors.muted),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
