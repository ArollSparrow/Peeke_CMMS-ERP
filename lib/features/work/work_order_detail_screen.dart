import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import 'work_providers.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  Future<void> _status(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(workRepositoryProvider).updateOrderStatus(
            orderId,
            status: status,
            completedBy: user?.email,
          );
      ref.invalidate(workOrderByIdProvider(orderId));
      ref.invalidate(workOrdersListProvider);
      ref.invalidate(openWorkOrdersCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status → $status')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrderByIdProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: async.when(
          data: (w) => Text(w?.woNumber ?? 'Work order'),
          loading: () => const Text('Work order'),
          error: (_, __) => const Text('Work order'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (wo) {
          if (wo == null) {
            return const Center(child: Text('Not found'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    wo.status.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GlossColors.accent,
                    ),
                  ),
                  subtitle: Text('${wo.jobType} · ${wo.priority} priority'),
                ),
              ),
              _row('Client', wo.clientName),
              _row('Site', wo.clientSite),
              _row('System', [
                if (wo.systemType != null) wo.systemType!,
                if (wo.systemModel != null) wo.systemModel!,
                if (wo.systemSerial != null) wo.systemSerial!,
              ].join(' · ')),
              _row('Description', wo.description),
              _row('Fault', wo.faultDescription),
              _row('Technician', wo.assignedTechnician),
              _row('Requested by', wo.requestedBy),
              _row('Notes', wo.notes),
              if (wo.needsProcurement)
                const ListTile(
                  leading: Icon(Icons.local_shipping_outlined),
                  title: Text('Needs procurement'),
                ),
              const SizedBox(height: 16),
              const Text(
                'ACTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GlossColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              if (wo.status == 'open') ...[
                FilledButton(
                  onPressed: () => _status(context, ref, 'in_progress'),
                  child: const Text('Start work'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _status(context, ref, 'on_hold'),
                  child: const Text('Put on hold'),
                ),
              ],
              if (wo.status == 'in_progress') ...[
                FilledButton(
                  onPressed: () => _status(context, ref, 'completed'),
                  child: const Text('Mark completed'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _status(context, ref, 'on_hold'),
                  child: const Text('Put on hold'),
                ),
              ],
              if (wo.status == 'on_hold') ...[
                FilledButton(
                  onPressed: () => _status(context, ref, 'in_progress'),
                  child: const Text('Resume'),
                ),
              ],
              if (wo.isOpen) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _status(context, ref, 'cancelled'),
                  child: const Text(
                    'Cancel work order',
                    style: TextStyle(color: GlossColors.danger),
                  ),
                ),
              ],
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
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: GlossColors.muted)),
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
