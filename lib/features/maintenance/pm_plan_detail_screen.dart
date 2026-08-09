import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import 'maintenance_models.dart';
import 'maintenance_providers.dart';

/// M3: plan execution — generate work, soft-open handling, linked work, meter foundation.
class PmPlanDetailScreen extends ConsumerWidget {
  const PmPlanDetailScreen({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pmPlanByIdProvider(planId));
    final linked = ref.watch(pmPlanLinkedWorkProvider(planId));
    return Scaffold(
      appBar: AppBar(
        title: async.when(
          data: (p) => Text(p?.title ?? 'PM Plan'),
          loading: () => const Text('PM Plan'),
          error: (_, __) => const Text('PM Plan'),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/maintenance/plans/$planId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          if (p == null) return const Center(child: Text('Not found'));
          final generatesLabel =
              p.generates == 'work_request' ? 'Work Request' : 'Work Order';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(p.planStatus.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: GlossColors.accent)),
                  subtitle: Text(p.systemLine),
                ),
              ),
              _row('Interval', p.intervalLabel),
              _row('Trigger', p.triggerType),
              _row('Priority', p.priority),
              _row('Auto generate', p.autoGenerateWo ? p.generates : 'Off'),
              if (p.nextDueAt != null)
                _row('Next due', p.nextDueAt!.toLocal().toString().split('.').first),
              if (p.lastMeterReading != null)
                _row('Last meter', p.lastMeterReading!.toString()),
              if (p.nextDueMeter != null)
                _row('Next due meter', p.nextDueMeter!.toString()),
              if (p.description != null && p.description!.isNotEmpty)
                _row('Description', p.description),
              const SizedBox(height: 12),
              const Text('Execute',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: p.isActive
                    ? () => _generate(context, ref, p)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: Text('Generate $generatesLabel now'),
              ),
              if (!p.isActive)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Activate the plan before generating work.',
                      style: TextStyle(fontSize: 12, color: GlossColors.muted)),
                ),
              if (p.isMeter) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _recordMeter(context, ref, p),
                  icon: const Icon(Icons.speed, size: 18),
                  label: const Text('Record meter reading'),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Linked work',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              linked.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (items) {
                  if (items.isEmpty) {
                    return const Card(
                      child: ListTile(
                        dense: true,
                        title: Text('No linked work yet',
                            style: TextStyle(color: GlossColors.muted)),
                      ),
                    );
                  }
                  return Column(
                    children: items.map((m) {
                      final kind = m['kind'] as String? ?? '';
                      final id = m['id'] as String? ?? '';
                      final number = m['number'] as String? ?? '—';
                      final status = m['status'] as String? ?? '';
                      final isOpen = m['is_open'] == true;
                      final label = kind == 'work_request' ? 'WR $number' : 'WO $number';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          title: Text(label),
                          subtitle: Text(status,
                              style: TextStyle(
                                color: isOpen ? const Color(0xFF3B82F6) : GlossColors.muted,
                                fontSize: 12,
                              )),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            if (kind == 'work_request') {
                              context.push('/work/requests/$id');
                            } else {
                              context.push('/work/orders/$id');
                            }
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () async {
                  final active = !(p.isActive);
                  await ref.read(maintenanceRepositoryProvider).updatePmPlan(planId, {
                    'is_active': active,
                  });
                  ref.invalidate(pmPlanByIdProvider(planId));
                  ref.invalidate(pmPlansListProvider);
                  ref.invalidate(duePmCountProvider);
                },
                child: Text(p.isActive ? 'Deactivate plan' : 'Activate plan'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete PM plan?'),
                      content: Text(
                          '"${p.title}" will be removed. Existing WOs are not affected.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await ref.read(maintenanceRepositoryProvider).deletePmPlan(planId);
                  ref.invalidate(pmPlansListProvider);
                  ref.invalidate(duePmCountProvider);
                  if (context.mounted) context.go('/maintenance/plans');
                },
                child: const Text('Delete plan',
                    style: TextStyle(color: GlossColors.danger)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref, PmPlan plan) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(maintenanceRepositoryProvider);
    final generatesLabel =
        plan.generates == 'work_request' ? 'work request' : 'work order';

    Future<void> doGen({required bool force}) async {
      try {
        final result = await repo.generateWorkFromPlan(
          plan: plan,
          requestedBy: user?.email,
          force: force,
        );
        ref.invalidate(pmPlanByIdProvider(planId));
        ref.invalidate(pmPlansListProvider);
        ref.invalidate(duePmCountProvider);
        ref.invalidate(pmPlanLinkedWorkProvider(planId));
        if (!context.mounted) return;
        final kind = result['kind'];
        final id = result['id'] as String;
        final number = result['number'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kind == 'work_request'
                  ? 'Created WR $number'
                  : 'Created WO $number',
            ),
          ),
        );
        if (kind == 'work_request') {
          context.push('/work/requests/$id');
        } else {
          context.push('/work/orders/$id');
        }
      } catch (e) {
        if (e is StateError && e.message == 'OPEN_WORK_EXISTS') {
          if (!context.mounted) return;
          final go = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Open work already exists'),
              content: Text(
                'This plan already has open work'
                '${plan.openWrNumber != null ? ' (WR ${plan.openWrNumber})' : ''}'
                '${plan.openWoCount > 0 ? ' (${plan.openWoCount} open WO)' : ''}. '
                'Open existing, or generate another $generatesLabel anyway?',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'open'),
                    child: const Text('View linked')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'force'),
                    child: const Text('Generate anyway')),
              ],
            ),
          );
          if (go == 'force') {
            await doGen(force: true);
          }
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Generate $generatesLabel?'),
        content: Text(
          'Create a ${plan.generates == 'work_request' ? 'work request' : 'work order'} '
          'from "${plan.title}"'
          '${plan.isMeter ? '' : ' and advance the next due date'}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirm != true) return;
    await doGen(force: false);
  }

  Future<void> _recordMeter(BuildContext context, WidgetRef ref, PmPlan plan) async {
    final ctrl = TextEditingController(
      text: plan.lastMeterReading?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meter reading'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Current hour meter'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final reading = double.tryParse(ctrl.text.trim());
    if (reading == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number')),
        );
      }
      return;
    }
    try {
      await ref.read(maintenanceRepositoryProvider).recordMeterReading(
            planId: planId,
            reading: reading,
          );
      ref.invalidate(pmPlanByIdProvider(planId));
      ref.invalidate(pmPlansListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meter reading saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _row(String l, String? v) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(l, style: const TextStyle(fontSize: 12, color: GlossColors.muted)),
        subtitle: Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
