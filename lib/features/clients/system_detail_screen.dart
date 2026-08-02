import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'client_providers.dart';

class SystemDetailScreen extends ConsumerWidget {
  const SystemDetailScreen({super.key, required this.systemId});

  final String systemId;

  Future<void> _delete(BuildContext context, WidgetRef ref, String? clientId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete system?'),
        content: const Text(
          'This removes the asset record. Work history in later phases may reference it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GlossColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(systemRepositoryProvider).delete(systemId);
      ref.invalidate(systemsListProvider);
      if (clientId != null) {
        ref.invalidate(systemsByClientProvider(clientId));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System deleted')),
        );
        context.go('/systems');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemByIdProvider(systemId));

    return Scaffold(
      appBar: AppBar(
        title: async.when(
          data: (s) => Text(s?.name ?? 'System'),
          loading: () => const Text('System'),
          error: (_, __) => const Text('System'),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => context.push('/systems/$systemId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () {
              final s = async.valueOrNull;
              _delete(context, ref, s?.clientId);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) {
          if (s == null) {
            return const Center(child: Text('System not found'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.systemLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: GlossColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (s.clientId != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(s.clientName ?? 'Client'),
                    subtitle: Text(
                      [
                        if (s.clientSite != null) s.clientSite!,
                        if (s.clientLocation != null) s.clientLocation!,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/clients/${s.clientId}'),
                  ),
                ),
              _row('Serial', s.serialNumber),
              _row('Model', s.model),
              _row('Type', s.type),
              _row('Capacity', s.capacityLabel.isEmpty ? null : s.capacityLabel),
              _row('Barcode', s.barcode),
              _row(
                'Installation',
                s.installationDate?.toIso8601String().split('T').first,
              ),
              _row(
                'Registration',
                s.registrationDate?.toIso8601String().split('T').first,
              ),
              _row('Fuel tank (L)', s.fuelTankCapacity?.toString()),
              _row('Initial hour meter', s.initialHourMeter?.toString()),
              _row('Initial energy meter', s.initialEnergyMeter?.toString()),
              _row('Operation type', s.operationType),
              _row('Notes', s.notes),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(
          label,
          style: const TextStyle(fontSize: 12, color: GlossColors.muted),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: GlossColors.ink,
          ),
        ),
      ),
    );
  }
}
