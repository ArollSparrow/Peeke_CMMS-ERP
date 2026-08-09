import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'maintenance_models.dart';
import 'maintenance_providers.dart';

/// Full detail for a maintenance record (job card / service history entry).
/// Supports light edit of narrative fields and deep-links to WO / job card.
class MaintenanceRecordDetailScreen extends ConsumerWidget {
  const MaintenanceRecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maintenanceRecordByIdProvider(recordId));

    return Scaffold(
      appBar: AppBar(
        title: async.when(
          data: (r) => Text(r?.title ?? 'Service record'),
          loading: () => const Text('Service record'),
          error: (_, __) => const Text('Service record'),
        ),
        actions: [
          async.maybeWhen(
            data: (r) {
              if (r == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Edit findings / work done',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editNarrative(context, ref, r),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (record) {
          if (record == null) {
            return const Center(child: Text('Record not found'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    record.status.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GlossColors.accent,
                    ),
                  ),
                  subtitle: Text(
                    '${record.jobType}'
                    '${record.performedAt != null ? ' · ${record.performedAt!.toLocal().toString().substring(0, 16)}' : ''}',
                  ),
                ),
              ),
              _row('Title', record.title),
              _row('Client', record.clientName),
              _row(
                'System',
                [
                  if (record.systemType != null) record.systemType!,
                  if (record.systemSerial != null) record.systemSerial!,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              _row('Performed by', record.performedBy),
              if (record.hourMeter != null)
                _row('Hour meter', '${record.hourMeter}'),
              if (record.downtimeHours > 0)
                _row('Downtime', '${record.downtimeHours} h'),
              _row('Findings', record.findings),
              _row('Work done', record.workDone),
              _row('Parts used', record.partsUsed),
              _row('Notes', record.notes),

              if (record.workOrderId != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'LINKED WORK ORDER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GlossColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_outlined,
                        color: GlossColors.accent),
                    title: const Text('Open work order'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/work/orders/${record.workOrderId}'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined,
                        color: GlossColors.accent),
                    title: const Text('Job card view'),
                    subtitle: const Text(
                      'Read-only card with WO parts',
                      style: TextStyle(fontSize: 12, color: GlossColors.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                        '/work/orders/${record.workOrderId}/job-card'),
                  ),
                ),
              ],

              if (record.pmPlanId != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat_outlined,
                        color: GlossColors.accent),
                    title: const Text('Related PM plan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/maintenance/plans/${record.pmPlanId}'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editNarrative(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRecord record,
  ) async {
    final findingsCtrl = TextEditingController(text: record.findings ?? '');
    final workDoneCtrl = TextEditingController(text: record.workDone ?? '');
    final notesCtrl = TextEditingController(text: record.notes ?? '');
    final partsCtrl = TextEditingController(text: record.partsUsed ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit service record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findingsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Findings'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: workDoneCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Work done'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: partsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Parts used'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) {
      findingsCtrl.dispose();
      workDoneCtrl.dispose();
      notesCtrl.dispose();
      partsCtrl.dispose();
      return;
    }

    try {
      await ref.read(maintenanceRepositoryProvider).updateRecord(
            record.id,
            findings: findingsCtrl.text.trim(),
            workDone: workDoneCtrl.text.trim(),
            notes: notesCtrl.text.trim(),
            partsUsed: partsCtrl.text.trim(),
          );
      ref.invalidate(maintenanceRecordByIdProvider(record.id));
      ref.invalidate(maintenanceRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      findingsCtrl.dispose();
      workDoneCtrl.dispose();
      notesCtrl.dispose();
      partsCtrl.dispose();
    }
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
