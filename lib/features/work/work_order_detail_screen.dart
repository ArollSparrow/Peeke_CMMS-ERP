import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../maintenance/maintenance_providers.dart';
import '../org/org_providers.dart';
import '../procurement/procurement_providers.dart';
import 'job_card_screen.dart';
import 'work_models.dart';
import 'work_providers.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(workOrderByIdProvider(orderId));
    ref.invalidate(workOrdersListProvider);
    ref.invalidate(openWorkOrdersCountProvider);
    ref.invalidate(workOrderEventsProvider(orderId));
    ref.invalidate(workOrderPartsProvider(orderId));
    ref.invalidate(workOrderLinkedPosProvider(orderId));
    ref.invalidate(sparePartsListProvider);
    ref.invalidate(purchaseOrdersListProvider);
    ref.invalidate(jobCardByWoProvider(orderId));
    ref.invalidate(maintenanceRecordsProvider);
  }

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
      _invalidateAll(ref);
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

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel work order'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            hintText: 'Why this work order is cancelled',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: GlossColors.danger),
            child: const Text('Cancel WO'),
          ),
        ],
      ),
    );
    if (ok != true) {
      notesCtrl.dispose();
      return;
    }
    final notes = notesCtrl.text.trim();
    notesCtrl.dispose();
    if (notes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancellation reason is required')),
        );
      }
      return;
    }
    await _status(context, ref, 'cancelled', notes: notes);
  }

  /// Complete WO with optional job card + downtime (Slice D + E polish).
  Future<void> _completeWithNotes(BuildContext context, WidgetRef ref) async {
    final wo = await ref.read(workOrderByIdProvider(orderId).future);
    if (wo == null || !context.mounted) return;

    final existingParts = await ref.read(workOrderPartsProvider(orderId).future);
    final pendingExt = existingParts
        .where((p) => p.isExternal && !p.isReceived)
        .length;
    if (pendingExt > 0 && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Parts still open'),
          content: Text(
            '$pendingExt external part(s) are not marked received yet. '
            'Complete this work order anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) return;
    }

    final workDoneCtrl = TextEditingController();
    final findingsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final downtimeCtrl = TextEditingController();
    final hourMeterCtrl = TextEditingController();
    var createJobCard = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Complete work order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: workDoneCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Work done *',
                    hintText: 'What was performed…',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: findingsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Findings (optional)',
                    hintText: 'Root cause, observations…',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Completion notes (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hourMeterCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Hour meter (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: downtimeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Downtime hours (optional)',
                    hintText: 'e.g. 2.5',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Create job card'),
                  subtitle: const Text(
                    'Maintenance record linked to this WO (recommended)',
                    style: TextStyle(fontSize: 12, color: GlossColors.muted),
                  ),
                  value: createJobCard,
                  onChanged: (v) => setLocal(() => createJobCard = v),
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
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) {
      workDoneCtrl.dispose();
      findingsCtrl.dispose();
      notesCtrl.dispose();
      downtimeCtrl.dispose();
      hourMeterCtrl.dispose();
      return;
    }

    final workDone = workDoneCtrl.text.trim();
    final findings = findingsCtrl.text.trim();
    final notes = notesCtrl.text.trim();
    final downtimeHours = double.tryParse(downtimeCtrl.text.trim()) ?? 0;
    final hourMeter = double.tryParse(hourMeterCtrl.text.trim());
    workDoneCtrl.dispose();
    findingsCtrl.dispose();
    notesCtrl.dispose();
    downtimeCtrl.dispose();
    hourMeterCtrl.dispose();

    if (workDone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work done is required')),
        );
      }
      return;
    }

    final user = ref.read(currentUserProvider);
    final actor = user?.email;

    try {
      final completionNotes = [
        if (workDone.isNotEmpty) workDone,
        if (findings.isNotEmpty) 'Findings: $findings',
        if (notes.isNotEmpty) notes,
      ].join('\n');

      await ref.read(workRepositoryProvider).updateOrderStatus(
            orderId,
            status: 'completed',
            completedBy: actor,
            notes: completionNotes.isEmpty ? null : completionNotes,
            fromStatus: 'in_progress',
          );

      String? recordId;
      var didCreateJobCard = false;
      if (createJobCard) {
        final existing = await ref
            .read(maintenanceRepositoryProvider)
            .getRecordByWorkOrderId(orderId);
        if (existing != null) {
          recordId = existing.id;
        } else {
          final parts = await ref.read(workOrderPartsProvider(orderId).future);
          final partsSummary = parts.isEmpty
              ? null
              : parts
                  .map((p) =>
                      '${p.partName} × ${p.qtyRequired}${p.unitCost > 0 ? ' @ ${p.unitCost}' : ''}')
                  .join('; ');

          final record =
              await ref.read(maintenanceRepositoryProvider).createRecord(
                    organizationId: wo.organizationId,
                    systemId: wo.systemId,
                    title:
                        '${wo.woNumber ?? 'WO'} — ${wo.description ?? 'Job card'}',
                    workOrderId: orderId,
                    jobType: wo.jobType,
                    findings: findings.isEmpty ? null : findings,
                    workDone: workDone,
                    partsUsed: partsSummary,
                    hourMeter: hourMeter,
                    downtimeHours: downtimeHours > 0 ? downtimeHours : 0,
                    performedBy: wo.assignedTechnician ?? actor,
                    notes: notes.isEmpty ? null : notes,
                    systemType: wo.systemType,
                    systemSerial: wo.systemSerial,
                    clientName: wo.clientName,
                  );
          recordId = record.id;
          didCreateJobCard = true;
        }
      }

      if (downtimeHours > 0) {
        await ref.read(maintenanceRepositoryProvider).logDowntime(
              organizationId: wo.organizationId,
              systemId: wo.systemId,
              workOrderId: orderId,
              maintenanceRecordId: recordId,
              hours: downtimeHours,
              reason: findings.isNotEmpty
                  ? findings
                  : (wo.faultDescription ?? 'Maintenance downtime'),
              category: 'maintenance',
              loggedBy: actor,
              systemType: wo.systemType,
              systemSerial: wo.systemSerial,
              clientName: wo.clientName,
              notes: notes.isEmpty ? null : notes,
            );
      }

      _invalidateAll(ref);

      if (context.mounted) {
        final msg = [
          'Work order completed',
          if (didCreateJobCard) '· job card created',
          if (createJobCard && !didCreateJobCard && recordId != null)
            '· job card already linked',
          if (downtimeHours > 0) '· ${downtimeHours}h downtime',
        ].join(' ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: (createJobCard || recordId != null)
                ? SnackBarAction(
                    label: 'Job card',
                    onPressed: () =>
                        context.push('/work/orders/$orderId/job-card'),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complete failed: $e')),
        );
      }
    }
  }
