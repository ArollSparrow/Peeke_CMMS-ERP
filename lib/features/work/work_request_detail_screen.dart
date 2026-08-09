import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../maintenance/maintenance_providers.dart';
import 'work_providers.dart';

class WorkRequestDetailScreen extends ConsumerWidget {
  const WorkRequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    final wr = await ref.read(workRepositoryProvider).getRequest(requestId);
    if (wr == null || !context.mounted) return;
    final user = ref.read(currentUserProvider);

    final techs = await ref.read(techniciansListProvider.future);
    if (!context.mounted) return;

    String? assigned;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create work order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Convert ${wr.wrNumber ?? 'request'} to a work order.',
                style: const TextStyle(color: GlossColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (techs.isEmpty)
                const Text(
                  'No technicians yet — assign later from the work order.',
                  style: TextStyle(fontSize: 12, color: GlossColors.muted),
                )
              else
                DropdownButtonFormField<String?>(
                  value: assigned,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assign technician (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— Assign later —'),
                    ),
                    ...techs.map(
                      (t) => DropdownMenuItem(
                        value: t.name,
                        child: Text(t.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => assigned = v),
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
              child: const Text('Create WO'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final wo = await ref.read(workRepositoryProvider).convertRequestToOrder(
            wr,
            reviewedBy: user?.email,
            assignedTechnician: assigned,
          );
      ref.invalidate(workRequestsListProvider);
      ref.invalidate(workOrdersListProvider);
      ref.invalidate(workRequestByIdProvider(requestId));
      ref.invalidate(openWorkOrdersCountProvider);
      ref.invalidate(pendingWorkRequestsCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              assigned == null
                  ? 'Converted to ${wo.woNumber}'
                  : 'Converted to ${wo.woNumber} · $assigned',
            ),
          ),
        );
        context.go('/work/orders/${wo.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Convert failed: $e')),
        );
      }
    }
  }

  Future<void> _approveOnly(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(workRepositoryProvider).updateRequestStatus(
            requestId,
            status: 'approved',
            reviewedBy: user?.email,
          );
      ref.invalidate(workRequestByIdProvider(requestId));
      ref.invalidate(workRequestsListProvider);
      ref.invalidate(pendingWorkRequestsCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approved — convert when ready')),
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
    final user = ref.read(currentUserProvider);
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject work request'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            hintText: 'Why this request is rejected',
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
      await ref.read(workRepositoryProvider).updateRequestStatus(
            requestId,
            status: 'rejected',
            reviewedBy: user?.email,
            reviewNotes: notes,
          );
      ref.invalidate(workRequestByIdProvider(requestId));
      ref.invalidate(workRequestsListProvider);
      ref.invalidate(pendingWorkRequestsCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected')),
        );
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
    final async = ref.watch(workRequestByIdProvider(requestId));
    return Scaffold(
      appBar: AppBar(
        title: async.when(
          data: (w) => Text(w?.wrNumber ?? 'Request'),
          loading: () => const Text('Request'),
          error: (_, __) => const Text('Request'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (wr) {
          if (wr == null) return const Center(child: Text('Not found'));
          final canAct = wr.status == 'pending' || wr.status == 'approved';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(wr.status.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: GlossColors.accent)),
                  subtitle: Text('${wr.jobType} · ${wr.priority} priority'),
                ),
              ),
              _row('Client', wr.clientName),
              _row('Site', wr.clientSite),
              _row('System', [
                if (wr.systemType != null) wr.systemType!,
                if (wr.systemModel != null) wr.systemModel!,
                if (wr.systemSerial != null) wr.systemSerial!,
              ].join(' · ')),
              _row('Description', wr.description),
              _row('Fault', wr.faultDescription),
              _row('Requested by', wr.requestedBy),
              _row('Reviewed by', wr.reviewedBy),
              _row('Review notes', wr.reviewNotes),
              _row('Notes', wr.notes),
              if (wr.needsProcurement)
                const ListTile(
                  leading: Icon(Icons.local_shipping_outlined),
                  title: Text('Needs procurement'),
                ),
              if (wr.workOrderId != null)
                ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: const Text('Linked work order'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/work/orders/${wr.workOrderId}'),
                ),
              if (canAct) ...[
                const SizedBox(height: 16),
                if (wr.status == 'pending') ...[
                  FilledButton(
                    onPressed: () => _convert(context, ref),
                    child: const Text('Approve & create work order'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _approveOnly(context, ref),
                    child: const Text('Approve only'),
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
                if (wr.status == 'approved')
                  FilledButton(
                    onPressed: () => _convert(context, ref),
                    child: const Text('Create work order'),
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
        title: Text(label, style: const TextStyle(fontSize: 12, color: GlossColors.muted)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: GlossColors.ink)),
      ),
    );
  }
}
