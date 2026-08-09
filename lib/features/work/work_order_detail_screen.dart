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

  /// Slice D: complete WO with optional job card + downtime.
  Future<void> _completeWithNotes(BuildContext context, WidgetRef ref) async {
    final wo = await ref.read(workOrderByIdProvider(orderId).future);
    if (wo == null || !context.mounted) return;

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
          );

      String? recordId;
      if (createJobCard) {
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

      final client = ref.read(supabaseClientProvider);
      await client.from('work_order_events').insert({
        'organization_id': wo.organizationId,
        'work_order_id': orderId,
        'action': 'completed',
        'stage': 'completion',
        'from_status': 'in_progress',
        'to_status': 'completed',
        'actor': actor,
        'notes': [
          if (createJobCard) 'Job card created',
          if (downtimeHours > 0) 'Downtime ${downtimeHours}h logged',
        ].join(' · '),
      });

      _invalidateAll(ref);

      if (context.mounted) {
        final msg = [
          'Work order completed',
          if (createJobCard) '· job card created',
          if (downtimeHours > 0) '· ${downtimeHours}h downtime',
        ].join(' ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: createJobCard
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

  Future<void> _submitForApproval(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(workRepositoryProvider).submitForApproval(
            id: orderId,
            actor: user?.email,
          );
      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for approval')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    if (!ref.read(orgCapabilitiesProvider).canApproveWork) return;
    final user = ref.read(currentUserProvider);
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve work order'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true) {
      notesCtrl.dispose();
      return;
    }
    final notes = notesCtrl.text.trim();
    notesCtrl.dispose();
    try {
      await ref.read(workRepositoryProvider).approveOrder(
            id: orderId,
            approvedBy: user?.email,
            notes: notes.isEmpty ? null : notes,
          );
      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approved — ready to execute')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    if (!ref.read(orgCapabilitiesProvider).canApproveWork) return;
    final user = ref.read(currentUserProvider);
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject work order'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            hintText: 'Why this WO is rejected',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: GlossColors.danger),
            child: const Text('Reject'),
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
          const SnackBar(content: Text('Rejection reason is required')),
        );
      }
      return;
    }
    try {
      await ref.read(workRepositoryProvider).rejectOrder(
            id: orderId,
            rejectedBy: user?.email,
            notes: notes,
          );
      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work order rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
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
      _invalidateAll(ref);
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
    final catalogue = await ref.read(sparePartsListProvider.future);
    if (!context.mounted) return;

    SparePart? selectedCatalogue;
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: '0');
    var source = 'internal';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add required part'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: source,
                  decoration: const InputDecoration(labelText: 'Source'),
                  items: const [
                    DropdownMenuItem(
                        value: 'internal', child: Text('Internal (from stock)')),
                    DropdownMenuItem(
                        value: 'external', child: Text('External (buy / PO)')),
                  ],
                  onChanged: (v) => setLocal(() {
                    source = v ?? 'internal';
                    if (source == 'external') selectedCatalogue = null;
                  }),
                ),
                const SizedBox(height: 8),
                if (source == 'internal' && catalogue.isNotEmpty) ...[
                  DropdownButtonFormField<SparePart?>(
                    value: selectedCatalogue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Catalogue part (required to Issue)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— Free text (cannot Issue) —'),
                      ),
                      ...catalogue.map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.name} (on hand ${p.quantityOnHand})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (p) => setLocal(() {
                      selectedCatalogue = p;
                      if (p != null) {
                        nameCtrl.text = p.name;
                        costCtrl.text = (p.unitCost).toString();
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                if (source == 'internal' && catalogue.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No catalogue parts yet. Add under Inventory, then pick here to enable Issue from stock. Free-text internal lines cannot be issued.',
                      style: TextStyle(fontSize: 12, color: GlossColors.muted),
                    ),
                  ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Part name *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty required'),
                ),
                if (source == 'external') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: costCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Unit cost (optional)',
                      hintText: 'Used for PO total',
                    ),
                  ),
                ],
              ],
            ),
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
      costCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
    final unitCost = double.tryParse(costCtrl.text.trim()) ?? 0;
    final cat = selectedCatalogue;
    nameCtrl.dispose();
    qtyCtrl.dispose();
    costCtrl.dispose();
    if (name.isEmpty) return;

    try {
      await ref.read(workRepositoryProvider).addPart(
            organizationId: wo.organizationId,
            workOrderId: orderId,
            partName: name,
            sparePartId: cat?.id,
            partNumber: cat?.partNumber,
            source: source,
            qtyRequired: qty,
            unitCost: source == 'external'
                ? unitCost
                : (cat?.unitCost ?? unitCost),
          );
      _invalidateAll(ref);
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

  Future<void> _issuePart(
    BuildContext context,
    WidgetRef ref,
    WorkOrderPart part,
  ) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(workRepositoryProvider).issuePartFromStock(
            woPartId: part.id,
            performedBy: user?.email,
          );
      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Issued ${part.partName} from stock')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Issue failed: $e')),
        );
      }
    }
  }

  Future<void> _raisePo(
    BuildContext context, WidgetRef ref, WorkOrder wo,
  ) async {
    final vendors = await ref.read(vendorsListProvider.future);
    if (!context.mounted) return;

    String? vendorId;
    String? vendorName;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Raise purchase order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Creates a draft PO with all pending external parts that are not yet linked to a PO. '
                'Approve → Order → Receive in Procurement to put stock in and mark parts received.',
                style: TextStyle(fontSize: 12, color: GlossColors.muted),
              ),
              const SizedBox(height: 12),
              if (vendors.isEmpty)
                const Text(
                  'No vendors yet — PO will be created without a vendor. '
                  'Add vendors under Procurement.',
                  style: TextStyle(fontSize: 12),
                )
              else
                DropdownButtonFormField<String?>(
                  value: vendorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    ...vendors.map(
                      (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
                    ),
                  ],
                  onChanged: (id) => setLocal(() {
                    vendorId = id;
                    vendorName = null;
                    if (id != null) {
                      for (final v in vendors) {
                        if (v.id == id) {
                          vendorName = v.name;
                          break;
                        }
                      }
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create draft PO')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final user = ref.read(currentUserProvider);
    try {
      final po = await ref.read(workRepositoryProvider).createPoFromExternalParts(
            organizationId: wo.organizationId,
            workOrderId: orderId,
            woNumber: wo.woNumber ?? orderId,
            vendorId: vendorId,
            vendorName: vendorName,
            orderedBy: user?.email,
          );
      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Draft ${po.poNumber} created'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => context.push('/procurement/orders/${po.id}'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PO failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrderByIdProvider(orderId));
    final partsAsync = ref.watch(workOrderPartsProvider(orderId));
    final eventsAsync = ref.watch(workOrderEventsProvider(orderId));
    final posAsync = ref.watch(workOrderLinkedPosProvider(orderId));
    final caps = ref.watch(orgCapabilitiesProvider);

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
              _row('Approved by', wo.approvedBy),
              _row('Approval notes', wo.approvalNotes),
              _row('Notes', wo.notes),
              if (wo.needsProcurement)
                const ListTile(
                  leading: Icon(Icons.local_shipping_outlined),
                  title: Text('Needs procurement'),
                ),

              if (wo.status == 'completed') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/work/orders/$orderId/job-card'),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('View job card'),
                ),
              ],

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
                  final pendingExternal =
                      parts.where((p) => p.canRaisePo).length;
                  final allExternalReceived = parts
                      .where((p) => p.isExternal)
                      .every((p) => p.isReceived);
                  final hasExternal = parts.any((p) => p.isExternal);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (parts.isEmpty)
                        const Card(
                          child: ListTile(
                            dense: true,
                            title: Text('No parts yet',
                                style: TextStyle(color: GlossColors.muted)),
                          ),
                        )
                      else
                        ...parts.map(
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
                                _partSubtitle(p),
                                style: const TextStyle(
                                    color: GlossColors.muted, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (p.canIssueFromStock)
                                    TextButton(
                                      onPressed: () =>
                                          _issuePart(context, ref, p),
                                      child: const Text('Issue'),
                                    ),
                                  if (p.procurementStatus == 'pending' &&
                                      !p.hasLinkedPo)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20),
                                      onPressed: () async {
                                        await ref
                                            .read(workRepositoryProvider)
                                            .deletePart(p.id);
                                        _invalidateAll(ref);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (pendingExternal > 0) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _raisePo(context, ref, wo),
                          icon: const Icon(Icons.request_quote_outlined),
                          label: Text(
                            'Raise PO for $pendingExternal external part'
                            '${pendingExternal == 1 ? '' : 's'}',
                          ),
                        ),
                      ],
                      if (wo.status == 'open' &&
                          hasExternal &&
                          !allExternalReceived &&
                          pendingExternal == 0) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _status(context, ref, 'awaiting_parts'),
                          icon: const Icon(Icons.hourglass_top, size: 18),
                          label: const Text('Mark awaiting parts'),
                        ),
                      ],
                      if (wo.isAwaitingParts &&
                          hasExternal &&
                          allExternalReceived) ...[
                        const SizedBox(height: 8),
                        const Card(
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.check_circle_outline,
                                color: GlossColors.accent),
                            title: Text('All external parts received'),
                            subtitle: Text('Resume when ready to start work'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              const Text(
                'LINKED PURCHASE ORDERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GlossColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              posAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (pos) {
                  if (pos.isEmpty) {
                    return const Card(
                      child: ListTile(
                        dense: true,
                        title: Text('No POs linked yet',
                            style: TextStyle(color: GlossColors.muted)),
                      ),
                    );
                  }
                  return Column(
                    children: pos
                        .map(
                          (po) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.receipt_long_outlined,
                                  color: GlossColors.accent),
                              title: Text(po.poNumber),
                              subtitle: Text(
                                '${po.status} · ${po.vendorName ?? 'No vendor'}',
                                style: const TextStyle(
                                    color: GlossColors.muted, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context
                                  .push('/procurement/orders/${po.id}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),

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

              if (wo.isPendingApproval && caps.canApproveWork) ...[
                FilledButton(
                  onPressed: () => _approve(context, ref),
                  child: const Text('Approve'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: GlossColors.danger),
                  ),
                ),
              ],
              if (wo.isPendingApproval && !caps.canApproveWork)
                const Card(
                  child: ListTile(
                    dense: true,
                    title: Text('Awaiting approval'),
                    subtitle: Text(
                      'An owner or admin must approve this work order.',
                      style: TextStyle(color: GlossColors.muted, fontSize: 12),
                    ),
                  ),
                ),

              if (wo.isAwaitingParts) ...[
                FilledButton(
                  onPressed: () => _status(context, ref, 'open'),
                  child: const Text('Parts ready — resume'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _status(context, ref, 'in_progress'),
                  child: const Text('Resume & start work'),
                ),
              ],

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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _submitForApproval(context, ref),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Submit for approval'),
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

              if (wo.isActive && !wo.isPendingApproval) ...[
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

  String _partSubtitle(WorkOrderPart p) {
    final bits = <String>[
      'Qty ${p.qtyRequired}',
      p.source,
      p.procurementStatus,
    ];
    if (p.unitCost > 0) {
      bits.add('KES ${p.unitCost.toStringAsFixed(0)}');
    }
    if (p.source == 'internal' && p.sparePartId == null) {
      bits.add('no catalogue link — cannot Issue');
    }
    if (p.hasLinkedPo && p.procurementStatus == 'pending') {
      bits.add('draft PO linked');
    }
    return bits.join(' · ');
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
