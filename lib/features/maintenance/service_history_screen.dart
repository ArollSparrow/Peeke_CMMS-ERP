import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'maintenance_providers.dart';

class ServiceHistoryScreen extends ConsumerStatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  ConsumerState<ServiceHistoryScreen> createState() =>
      _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends ConsumerState<ServiceHistoryScreen> {
  String _q = '';
  String _jobTypeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(maintenanceRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service history'),
        actions: [
          IconButton(
            onPressed: () => context.push('/maintenance/jobs/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search title, client, system…',
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
              children: ['all', 'corrective', 'scheduled', 'inspection', 'other']
                  .map((s) {
                final sel = _jobTypeFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: sel,
                    onSelected: (_) => setState(() => _jobTypeFilter = s),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(maintenanceRecordsProvider);
                await ref.read(maintenanceRecordsProvider.future);
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
                  if (_jobTypeFilter != 'all') {
                    list = list
                        .where((r) => r.jobType == _jobTypeFilter)
                        .toList();
                  }
                  if (_q.isNotEmpty) {
                    list = list.where((r) {
                      final hay =
                          '${r.title} ${r.clientName ?? ''} ${r.systemType ?? ''} ${r.systemSerial ?? ''} ${r.performedBy ?? ''}'
                              .toLowerCase();
                      return hay.contains(_q);
                    }).toList();
                  }
                  if (list.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(items.isEmpty
                            ? 'No maintenance jobs yet'
                            : 'No matches'),
                      ),
                      Center(
                        child: FilledButton(
                          onPressed: () =>
                              context.push('/maintenance/jobs/new'),
                          child: const Text('Log first job'),
                        ),
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = list[i];
                      return Card(
                        child: ListTile(
                          title: Text(r.title),
                          subtitle: Text(
                            [
                              r.jobType,
                              if (r.systemType != null) r.systemType!,
                              if (r.clientName != null) r.clientName!,
                              if (r.performedAt != null)
                                r.performedAt!
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16),
                              if (r.workOrderId != null) 'from WO',
                            ].join(' · '),
                            style: const TextStyle(color: GlossColors.muted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r.downtimeHours > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    '${r.downtimeHours}h',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: GlossColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              Chip(
                                label: Text(r.status,
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                          onTap: () => context
                              .push('/maintenance/history/${r.id}'),
                        ),
                      );
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
