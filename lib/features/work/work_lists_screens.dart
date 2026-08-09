import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'work_models.dart';
import 'work_providers.dart';

class WorkHubScreen extends ConsumerWidget {
  const WorkHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWorkRequestsCountProvider).valueOrNull;
    final open = ref.watch(openWorkOrdersCountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Work loop')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context,
              icon: Icons.assignment_add,
              title: 'New work request',
              subtitle: 'Raise WR against a system',
              route: '/work/requests/new'),
          _tile(context,
              icon: Icons.inbox_outlined,
              title: 'Work requests',
              subtitle: pending == null ? 'Review & convert' : '$pending pending',
              route: '/work/requests'),
          _tile(context,
              icon: Icons.handyman_outlined,
              title: 'Work orders',
              subtitle: open == null ? 'Execute jobs' : '$open open',
              route: '/work/orders'),
          _tile(context,
              icon: Icons.add_task_outlined,
              title: 'New work order',
              subtitle: 'Create WO directly (skip WR)',
              route: '/work/orders/new'),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: GlossColors.accent),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}

class _StatusChipBar extends StatelessWidget {
  const _StatusChipBar({
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
  });

  final List<String?> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String Function(String?) labelOf;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: options.map((s) {
          final active = selected == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labelOf(s)),
              selected: active,
              onSelected: (_) => onSelected(s),
              selectedColor: Colors.white,
              backgroundColor: GlossColors.pageBg,
              side: BorderSide(
                color: active ? GlossColors.accent : Colors.white54,
                width: active ? 1.5 : 1,
              ),
              labelStyle: TextStyle(
                color: active ? GlossColors.ink : GlossColors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

Color? _priorityColor(String priority) {
  switch (priority) {
    case 'critical':
      return GlossColors.danger;
    case 'high':
      return const Color(0xFFE67E22);
    default:
      return null;
  }
}

bool _matchesSearch(String query, List<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final f in fields) {
    if (f != null && f.toLowerCase().contains(q)) return true;
  }
  return false;
}

class WorkRequestsListScreen extends ConsumerWidget {
  const WorkRequestsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(workRequestStatusFilterProvider);
    final search = ref.watch(workRequestSearchProvider);
    final async = ref.watch(workRequestsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work requests'),
        actions: [
          IconButton(
            onPressed: () => context.push('/work/requests/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search number, client, description…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => ref
                            .read(workRequestSearchProvider.notifier)
                            .state = '',
                      ),
              ),
              onChanged: (v) =>
                  ref.read(workRequestSearchProvider.notifier).state = v,
            ),
          ),
          _StatusChipBar(
            options: WorkRequestStatuses.filterChips,
            selected: filter,
            onSelected: (s) =>
                ref.read(workRequestStatusFilterProvider.notifier).state = s,
            labelOf: WorkRequestStatuses.label,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(workRequestsListProvider);
                await ref.read(workRequestsListProvider.future);
              },
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [Text('$e')]),
                data: (items) {
                  final filtered = items
                      .where((wr) => _matchesSearch(search, [
                            wr.wrNumber,
                            wr.clientName,
                            wr.description,
                            wr.faultDescription,
                            wr.systemType,
                            wr.systemSerial,
                            wr.status,
                          ]))
                      .toList();
                  if (filtered.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(search.isEmpty
                            ? 'No work requests in this filter'
                            : 'No matches for "$search"'),
                      ),
                      const SizedBox(height: 16),
                      if (search.isEmpty)
                        Center(
                          child: FilledButton(
                            onPressed: () =>
                                context.push('/work/requests/new'),
                            child: const Text('Create request'),
                          ),
                        ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final wr = filtered[i];
                      final pColor = _priorityColor(wr.priority);
                      return Card(
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(wr.wrNumber ?? wr.id)),
                              if (pColor != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    wr.priority,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: pColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${wr.subtitle}\n${wr.description ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: GlossColors.muted),
                          ),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(wr.status,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () =>
                              context.push('/work/requests/${wr.id}'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/work/requests/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class WorkOrdersListScreen extends ConsumerWidget {
  const WorkOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(workOrderStatusFilterProvider);
    final search = ref.watch(workOrderSearchProvider);
    final async = ref.watch(workOrdersListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work orders'),
        actions: [
          IconButton(
            onPressed: () => context.push('/work/orders/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search number, client, tech, description…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => ref
                            .read(workOrderSearchProvider.notifier)
                            .state = '',
                      ),
              ),
              onChanged: (v) =>
                  ref.read(workOrderSearchProvider.notifier).state = v,
            ),
          ),
          _StatusChipBar(
            options: WorkOrderStatuses.filterChips,
            selected: filter,
            onSelected: (s) =>
                ref.read(workOrderStatusFilterProvider.notifier).state = s,
            labelOf: WorkOrderStatuses.label,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(workOrdersListProvider);
                await ref.read(workOrdersListProvider.future);
              },
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [Text('$e')]),
                data: (items) {
                  final filtered = items
                      .where((wo) => _matchesSearch(search, [
                            wo.woNumber,
                            wo.clientName,
                            wo.description,
                            wo.faultDescription,
                            wo.assignedTechnician,
                            wo.systemType,
                            wo.systemSerial,
                            wo.status,
                          ]))
                      .toList();
                  if (filtered.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(search.isEmpty
                            ? 'No work orders in this filter'
                            : 'No matches for "$search"'),
                      ),
                      const SizedBox(height: 8),
                      if (search.isEmpty)
                        const Center(
                          child: Text(
                            'Convert a work request or create a WO directly.',
                            style: TextStyle(color: GlossColors.muted),
                          ),
                        ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final wo = filtered[i];
                      final pColor = _priorityColor(wo.priority);
                      return Card(
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(wo.woNumber ?? wo.id)),
                              if (pColor != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    wo.priority,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: pColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${wo.subtitle}\n${wo.description ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: GlossColors.muted),
                          ),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(wo.status,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () =>
                              context.push('/work/orders/${wo.id}'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/work/orders/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
