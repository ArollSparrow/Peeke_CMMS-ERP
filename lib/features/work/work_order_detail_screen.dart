import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../maintenance/maintenance_providers.dart';
import '../org/org_providers.dart';
import 'work_models.dart';
import 'work_providers.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  Future<void> _status(
    BuildContext context,
    WidgetRef ref,
    String status, {
    String? notes,
  }) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(workRepositoryProvider).updateOrderStatus(
            orderId,
            status: status,
            completedBy: user?.email,
            notes: notes,
          );
      ref.invalidate(workOrderByIdProvider(orderId));
      ref.invalidate(workOrdersListProvider);
      ref.invalidate(openWorkOrdersCountProvider);
      ref.invalidate(workOrderEventsProvider(orderId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status → $status')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _completeWithNotes(BuildContext context, WidgetRef ref) async {
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete work order'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Completion notes',
            hintText: 'Work done, findings…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _status(context, ref, 'completed',
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
    }
    notesCtrl.dispose();
  }

  Future<void> _assignTech(BuildContext context, WidgetRef ref) async {
    final techs = await ref.read(techniciansListProvider.future);
    if (!context.mounted) return;
    if (techs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add technicians under Maintenance first'),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Assign technician',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...techs.map(
              (t) => ListTile(
                title: Text(t.name),
                subtitle: t.specialisation != null
                    ? Text(t.specialisation!)
                    : null,
                onTap: () => Navigator.pop(ctx, t.name),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(workRepositoryProvider).assignTechnician(orderId, picked);
      ref.invalidate(workOrderByIdProvider(orderId));
      ref.invalidate(workOrderEventsProvider(orderId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assigned · $picked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _addPart(BuildContext context, WidgetRef ref, WorkOrder wo) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    var source = 'internal';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add required part'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Part name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: source,
                decoration: const InputDecoration(labelText: 'Source'),
                items: const [
                  DropdownMenuItem(value: 'internal', child: Text('Internal (stock)')),
                  DropdownMenuItem(value: 'external', child: Text('External (buy)')),
                ],
                onChanged: (v) => setLocal(() => source = v ?? 'internal'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true) {
      nameCtrl.dispose();
      qtyCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
    nameCtrl.dispose();
    qtyCtrl.dispose();
    if (name.isEmpty) return;
    try {
      await ref.read(workRepositoryProvider).addPart(
            organizationId: wo.organizationId,
            workOrderId: orderId,
            partName: name,
            source: source,
            qtyRequired: qty,
          );
      if (source == 'external') {
        await ref.read(workRepositoryProvider).updateOrderStatus(
              orderId,
              status: wo.status,
              notes: wo.notes,
            );
        // Flag procurement need without changing status
        await ref.read(supabaseClientProvider).from('work_orders').update({
          'needs_procurement': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', orderId);
      }
      ref.invalidate(workOrderPartsProvider(orderId));
      ref.invalidate(workOrderByIdProvider(orderId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Part added')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrderByIdProvider(orderId));
    final partsAsync = ref.watch(workOrderPartsProvider(orderId));
    final eventsAsync = ref.watch(workOrderEventsProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: async.when(
          data: (w) => Text(w?.woNumber ?? 'Work order'),
          loading: () => const Text('Work order'),
          error: (_, __) => const Text('Work order'),
        ),
        actions: [
          IconButton(
            tooltip: 'Assign technician',
            onPressed: () => _assignTech(context, ref),
            icon: const Icon(Icons.engineering_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (wo) {
          if (wo == null) return const Center(child: Text('Not found'));
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
              _row(
                'System',
                [
                  if (wo.systemType != null) wo.systemType!,
                  if (wo.systemModel != null) wo.systemModel!,
                  if (wo.systemSerial != null) wo.systemSerial!,
                ].join(' · '),
              ),
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

              // —— Required parts ——
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'REQUIRED PARTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GlossColors.muted,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addPart(context, ref, wo),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              partsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (parts) {
                  if (parts.isEmpty) {
                    return const Card(
                      child: ListTile(
                        dense: true,
                        title: Text('No parts yet',
                            style: TextStyle(color: GlossColors.muted)),
                      ),
                    );
                  }
                  return Column(
                    children: parts
                        .map(
                          (p) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                p.isExternal
                                    ? Icons.shopping_bag_outlined
                                    : Icons.inventory_2_outlined,
                                color: GlossColors.accent,
                              ),
                              title: Text(p.partName),
                              subtitle: Text(
                                'Qty ${p.qtyRequired} · ${p.source} · ${p.procurementStatus}',
                                style: const TextStyle(
                                    color: GlossColors.muted, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20),
                                onPressed: () async {
                                  await ref
                                      .read(workRepositoryProvider)
                                      .deletePart(p.id);
                                  ref.invalidate(
                                      workOrderPartsProvider(orderId));
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),

              // —— Activity ——
              const SizedBox(height: 16),
              const Text(
                'ACTIVITY LOG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GlossColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              eventsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (events) {
                  if (events.isEmpty) {
                    return const Card(
                      child: ListTile(
                        dense: true,
                        title: Text('No events yet',
                            style: TextStyle(color: GlossColors.muted)),
                      ),
                    );
                  }
                  return Column(
                    children: events
                        .map(
                          (e) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.timeline,
                                  color: GlossColors.accent),
                              title: Text(e.title),
                              subtitle: Text(
                                [
                                  if (e.actor != null) e.actor!,
                                  if (e.fromStatus != null)
                                    '${e.fromStatus} → ${e.toStatus}',
                                  if (e.notes != null && e.notes!.isNotEmpty)
                                    e.notes!,
                                ].join(' · '),
                                style: const TextStyle(
                                    color: GlossColors.muted, fontSize: 12),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
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
                  onPressed: () => _completeWithNotes(context, ref),
                  child: const Text('Mark completed'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _status(context, ref, 'on_hold'),
                  child: const Text('Put on hold'),
                ),
              ],
              if (wo.status == 'on_hold')
                FilledButton(
                  onPressed: () => _status(context, ref, 'in_progress'),
                  child: const Text('Resume'),
                ),
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
        title:
            Text(label, style: const TextStyle(fontSize: 12, color: GlossColors.muted)),
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
