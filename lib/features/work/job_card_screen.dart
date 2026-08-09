import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../maintenance/maintenance_models.dart';
import '../maintenance/maintenance_providers.dart';
import 'work_models.dart';
import 'work_providers.dart';

/// Read-only job card for a completed work order (maintenance record + WO parts).
class JobCardScreen extends ConsumerWidget {
  const JobCardScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final woAsync = ref.watch(workOrderByIdProvider(orderId));
    final recordAsync = ref.watch(jobCardByWoProvider(orderId));
    final partsAsync = ref.watch(workOrderPartsProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job card'),
      ),
      body: woAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (wo) {
          if (wo == null) return const Center(child: Text('Work order not found'));
          return recordAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (record) {
              if (record == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No job card yet. Complete this work order with “Create job card” enabled.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GlossColors.muted),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        wo.woNumber ?? 'Work order',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${record.jobType} · ${record.status}',
                        style: const TextStyle(color: GlossColors.muted),
                      ),
                    ),
                  ),
                  _row('Client', record.clientName ?? wo.clientName),
                  _row('Site', wo.clientSite),
                  _row(
                    'System',
                    [
                      if (record.systemType != null) record.systemType!,
                      if (record.systemSerial != null) record.systemSerial!,
                      if (wo.systemModel != null) wo.systemModel!,
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  _row('Technician', wo.assignedTechnician ?? record.performedBy),
                  _row('Performed by', record.performedBy),
                  _row(
                    'Performed at',
                    record.performedAt?.toLocal().toString().substring(0, 16),
                  ),
                  if (record.hourMeter != null)
                    _row('Hour meter', '${record.hourMeter}'),
                  if (record.downtimeHours > 0)
                    _row('Downtime', '${record.downtimeHours} h'),
                  _row('Fault', wo.faultDescription),
                  _row('Findings', record.findings),
                  _row('Work done', record.workDone),
                  _row('Notes', record.notes),

                  const SizedBox(height: 12),
                  const Text(
                    'PARTS USED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GlossColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  partsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                    data: (parts) {
                      if (parts.isEmpty) {
                        return const Card(
                          child: ListTile(
                            dense: true,
                            title: Text(
                              'Labour-only — no parts on this WO',
                              style: TextStyle(color: GlossColors.muted),
                            ),
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
                                  title: Text(p.partName),
                                  subtitle: Text(
                                    'Qty ${p.qtyRequired} · ${p.source} · ${p.procurementStatus}'
                                    '${p.unitCost > 0 ? ' · KES ${p.unitCost.toStringAsFixed(0)}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GlossColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              );
            },
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

final jobCardByWoProvider =
    FutureProvider.autoDispose.family<MaintenanceRecord?, String>((ref, woId) {
  return ref.watch(maintenanceRepositoryProvider).getRecordByWorkOrderId(woId);
});
