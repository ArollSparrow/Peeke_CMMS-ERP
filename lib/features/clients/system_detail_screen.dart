import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../maintenance/maintenance_models.dart';
import '../maintenance/maintenance_providers.dart';
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

  Color _planColor(String status) {
    switch (status) {
      case 'overdue':
        return GlossColors.danger;
      case 'due':
        return const Color(0xFFF59E0B);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'upcoming':
        return const Color(0xFF16A34A);
      default:
        return GlossColors.muted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemByIdProvider(systemId));
    final recordsAsync = ref.watch(maintenanceRecordsBySystemProvider(systemId));
    final plansAsync = ref.watch(pmPlansBySystemProvider(systemId));
    final downtimeAsync = ref.watch(downtimeEventsBySystemProvider(systemId));

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
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(systemByIdProvider(systemId));
              ref.invalidate(maintenanceRecordsBySystemProvider(systemId));
              ref.invalidate(pmPlansBySystemProvider(systemId));
              ref.invalidate(downtimeEventsBySystemProvider(systemId));
              await Future.wait([
                ref.read(systemByIdProvider(systemId).future),
                ref.read(maintenanceRecordsBySystemProvider(systemId).future),
                ref.read(pmPlansBySystemProvider(systemId).future),
                ref.read(downtimeEventsBySystemProvider(systemId).future),
              ]);
            },
            child: ListView(
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

                // ── M5 actions ──────────────────────────────────
                const SizedBox(height: 16),
                const Text(
                  'MAINTENANCE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GlossColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        '/maintenance/jobs/new?systemId=$systemId',
                      ),
                      icon: const Icon(Icons.build_circle_outlined, size: 18),
                      label: const Text('Log job'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        '/maintenance/plans/new?systemId=$systemId',
                      ),
                      icon: const Icon(Icons.event_repeat_outlined, size: 18),
                      label: const Text('New PM plan'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/maintenance/history'),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('All history'),
                    ),
                  ],
                ),

                // ── PM plans ────────────────────────────────────
                const SizedBox(height: 20),
                const Text(
                  'PM PLANS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GlossColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                plansAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (plans) {
                    if (plans.isEmpty) {
                      return const Card(
                        child: ListTile(
                          dense: true,
                          title: Text(
                            'No PM plans for this system',
                            style: TextStyle(color: GlossColors.muted),
                          ),
                        ),
                      );
                    }
                    final sorted = [...plans]..sort((a, b) {
                      const rank = {
                        'overdue': 0,
                        'due': 1,
                        'in_progress': 2,
                        'upcoming': 3,
                        'inactive': 4,
                      };
                      return (rank[a.planStatus] ?? 9)
                          .compareTo(rank[b.planStatus] ?? 9);
                    });
                    return Column(
                      children: sorted.take(5).map((p) {
                        final st = p.planStatus;
                        final col = _planColor(st);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(p.title),
                            subtitle: Text(
                              '${p.intervalLabel} · ${p.priority}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: GlossColors.muted,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: col.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: col.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                st.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: col,
                                ),
                              ),
                            ),
                            onTap: () =>
                                context.push('/maintenance/plans/${p.id}'),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // ── Recent service ──────────────────────────────
                const SizedBox(height: 20),
                const Text(
                  'RECENT SERVICE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GlossColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                recordsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (records) {
                    if (records.isEmpty) {
                      return const Card(
                        child: ListTile(
                          dense: true,
                          title: Text(
                            'No service history yet',
                            style: TextStyle(color: GlossColors.muted),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: records.take(5).map((r) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(r.title),
                            subtitle: Text(
                              [
                                r.jobType,
                                if (r.performedAt != null)
                                  r.performedAt!
                                      .toLocal()
                                      .toString()
                                      .substring(0, 16),
                                if (r.performedBy != null) r.performedBy!,
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: GlossColors.muted,
                              ),
                            ),
                            trailing: r.downtimeHours > 0
                                ? Text(
                                    '${r.downtimeHours}h',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: GlossColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right, size: 18),
                            onTap: () => context
                                .push('/maintenance/history/${r.id}'),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // ── Recent downtime ─────────────────────────────
                const SizedBox(height: 20),
                const Text(
                  'RECENT DOWNTIME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GlossColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                downtimeAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (events) {
                    if (events.isEmpty) {
                      return const Card(
                        child: ListTile(
                          dense: true,
                          title: Text(
                            'No downtime logged',
                            style: TextStyle(color: GlossColors.muted),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: events.take(5).map((e) {
                        final hrs = e.hours;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.timer_outlined,
                              color: GlossColors.danger,
                              size: 20,
                            ),
                            title: Text(
                              e.reason?.isNotEmpty == true
                                  ? e.reason!
                                  : e.category,
                            ),
                            subtitle: Text(
                              [
                                e.startedAt
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16),
                                if (hrs > 0)
                                  '${hrs.toStringAsFixed(hrs >= 10 ? 0 : 1)}h',
                                e.category,
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: GlossColors.muted,
                              ),
                            ),
                            trailing: e.workOrderId != null
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.assignment_outlined,
                                      size: 18,
                                    ),
                                    tooltip: 'Open work order',
                                    onPressed: () => context.push(
                                      '/work/orders/${e.workOrderId}',
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
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
