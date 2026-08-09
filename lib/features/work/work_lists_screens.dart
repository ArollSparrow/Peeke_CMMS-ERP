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

/// White-encircled status chips (same pattern as PO queue).
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

class WorkRequestsListScreen extends ConsumerWidget {
  const WorkRequestsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(workRequestStatusFilterProvider);
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
                  if (items.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 48),
                      const Center(child: Text('No work requests in this filter')),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: () => context.push('/work/requests/new'),
                          child: const Text('Create request'),
                        ),
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final wr = items[i];
                      return Card(
                        child: ListTile(
                          title: Text(wr.wrNumber ?? wr.id),
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
                          onTap: () => context.push('/work/requests/${wr.id}'),
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
                  if (items.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 48),
                      Center(child: Text('No work orders in this filter')),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Convert a work request or create a WO directly.',
                          style: TextStyle(color: GlossColors.muted),
                        ),
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final wo = items[i];
                      return Card(
                        child: ListTile(
                          title: Text(wo.woNumber ?? wo.id),
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
                          onTap: () => context.push('/work/orders/${wo.id}'),
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
