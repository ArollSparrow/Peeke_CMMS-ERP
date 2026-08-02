import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../org/org_providers.dart';
import 'client_providers.dart';

class SystemsListScreen extends ConsumerStatefulWidget {
  const SystemsListScreen({super.key});

  @override
  ConsumerState<SystemsListScreen> createState() => _SystemsListScreenState();
}

class _SystemsListScreenState extends ConsumerState<SystemsListScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(systemsListProvider);
    final org = ref.watch(activeOrganizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Systems'),
        actions: [
          if (org != null)
            IconButton(
              tooltip: 'Register system',
              onPressed: () => context.push('/systems/new'),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: org == null
          ? const Center(child: Text('Select an organization first'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search system, client, serial…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(systemsListProvider);
                      await ref.read(systemsListProvider.future);
                    },
                    child: async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Error: $e'),
                          ),
                        ],
                      ),
                      data: (items) {
                        final filtered = _query.isEmpty
                            ? items
                            : items.where((s) {
                                final hay =
                                    '${s.name} ${s.clientName ?? ''} ${s.serialNumber ?? ''} ${s.type ?? ''} ${s.model ?? ''}'
                                        .toLowerCase();
                                return hay.contains(_query);
                              }).toList();

                        if (filtered.isEmpty) {
                          return ListView(
                            children: [
                              const SizedBox(height: 48),
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      items.isEmpty
                                          ? 'No systems yet'
                                          : 'No matches',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        'Systems must belong to a client.',
                                        textAlign: TextAlign.center,
                                        style:
                                            TextStyle(color: GlossColors.muted),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          context.push('/systems/new'),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Register system'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final s = filtered[i];
                            return Card(
                              child: ListTile(
                                title: Text(s.name),
                                subtitle: Text(
                                  s.subtitle.isEmpty ? s.status : s.subtitle,
                                  style:
                                      const TextStyle(color: GlossColors.muted),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/systems/${s.id}'),
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
      floatingActionButton: org == null
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/systems/new'),
              child: const Icon(Icons.add),
            ),
    );
  }
}
