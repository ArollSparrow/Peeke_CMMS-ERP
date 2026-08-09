import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'maintenance_models.dart';
import 'maintenance_providers.dart';

class DowntimeListScreen extends ConsumerStatefulWidget {
  const DowntimeListScreen({super.key});

  @override
  ConsumerState<DowntimeListScreen> createState() => _DowntimeListScreenState();
}

class _DowntimeListScreenState extends ConsumerState<DowntimeListScreen> {
  String _q = '';
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(downtimeEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Downtime')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search reason, client, system…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: const [
                'all',
                'maintenance',
                'breakdown',
                'planned',
                'other',
              ].map((s) {
                final sel = _categoryFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: sel,
                    onSelected: (_) => setState(() => _categoryFilter = s),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(downtimeEventsProvider);
                await ref.read(downtimeEventsProvider.future);
              },
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$e'),
                  )
                ]),
                data: (items) {
                  var list = items;
                  if (_categoryFilter != 'all') {
                    list = list
                        .where((e) => e.category == _categoryFilter)
                        .toList();
                  }
                  if (_q.isNotEmpty) {
                    list = list.where((e) {
                      final hay =
                          '${e.reason ?? ''} ${e.clientName ?? ''} ${e.systemType ?? ''} ${e.systemSerial ?? ''} ${e.notes ?? ''} ${e.loggedBy ?? ''}'
                              .toLowerCase();
                      return hay.contains(_q);
                    }).toList();
                  }

                  if (list.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(items.isEmpty
                            ? 'No downtime logged yet'
                            : 'No matches'),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Downtime is recorded when a work order is completed with hours > 0.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: GlossColors.muted, fontSize: 13),
                        ),
                      ),
                    ]);
                  }

                  final totalHours =
                      list.fold<double>(0, (s, e) => s + e.hours);

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Card(
                          color: GlossColors.pageBg,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 18, color: GlossColors.danger),
                                const SizedBox(width: 8),
                                Text(
                                  '${list.length} event${list.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Text(
                                  '${totalHours.toStringAsFixed(1)} h total',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: GlossColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final e = list[i - 1];
                      return _DowntimeCard(event: e);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DowntimeCard extends StatelessWidget {
  const _DowntimeCard({required this.event});
  final DowntimeEvent event;

  @override
  Widget build(BuildContext context) {
    final hoursLabel = event.hours > 0
        ? '${event.hours.toStringAsFixed(event.hours < 10 ? 1 : 0)} h'
        : '—';
    final when = event.startedAt.toLocal().toString().substring(0, 16);
    final systemLine = [
      if (event.systemType != null && event.systemType!.isNotEmpty)
        event.systemType!,
      if (event.systemSerial != null && event.systemSerial!.isNotEmpty)
        event.systemSerial!,
      if (event.clientName != null && event.clientName!.isNotEmpty)
        event.clientName!,
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (event.workOrderId != null) {
            context.push('/work/orders/${event.workOrderId}');
          } else if (event.maintenanceRecordId != null) {
            context.push('/maintenance/history/${event.maintenanceRecordId}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.reason?.isNotEmpty == true
                          ? event.reason!
                          : 'Downtime',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: GlossColors.danger.withValues(alpha: 0.12),
                      border: Border.all(
                          color: GlossColors.danger.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      hoursLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GlossColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (systemLine.isNotEmpty)
                Text(systemLine,
                    style:
                        const TextStyle(color: GlossColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _badge(event.category),
                  const SizedBox(width: 6),
                  _badge(when),
                  if (event.workOrderId != null) ...[
                    const SizedBox(width: 6),
                    _badge('WO linked'),
                  ],
                  if (event.maintenanceRecordId != null &&
                      event.workOrderId == null) ...[
                    const SizedBox(width: 6),
                    _badge('Job card'),
                  ],
                  const Spacer(),
                  if (event.workOrderId != null ||
                      event.maintenanceRecordId != null)
                    const Icon(Icons.chevron_right,
                        size: 18, color: GlossColors.muted),
                ],
              ),
              if (event.notes != null && event.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(event.notes!,
                    style: const TextStyle(
                        fontSize: 12, color: GlossColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: GlossColors.pageBg,
          border: Border.all(color: GlossColors.border),
        ),
        child: Text(t,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      );
}
