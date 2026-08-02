import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'client_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientByIdProvider(clientId));
    final systemsAsync = ref.watch(systemsByClientProvider(clientId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: clientAsync.when(
            data: (c) => Text(c?.name ?? 'Client'),
            loading: () => const Text('Client'),
            error: (_, __) => const Text('Client'),
          ),
          actions: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => context.push('/clients/$clientId/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Systems'),
            ],
          ),
        ),
        body: clientAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (client) {
            if (client == null) {
              return const Center(child: Text('Client not found'));
            }
            return TabBarView(
              children: [
                _ProfileTab(client: client),
                _SystemsTab(
                  clientId: clientId,
                  systemsAsync: systemsAsync,
                  onRefresh: () async {
                    ref.invalidate(systemsByClientProvider(clientId));
                    await ref.read(systemsByClientProvider(clientId).future);
                  },
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/systems/new?clientId=$clientId'),
          icon: const Icon(Icons.add),
          label: const Text('Attach system'),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.client});
  final dynamic client;

  @override
  Widget build(BuildContext context) {
    final c = client;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (c.siteName != null) ...[
                  const SizedBox(height: 4),
                  Text('Site · ${c.siteName}',
                      style: const TextStyle(color: GlossColors.muted)),
                ],
                if (c.location != null) ...[
                  const SizedBox(height: 2),
                  Text('Location · ${c.location}',
                      style: const TextStyle(color: GlossColors.muted)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _info('Contact', c.contact),
        _info('Phone', c.phone),
        _info('Email', c.email),
        _info('Account manager', c.accountManager),
        _info('Billing address', c.billingAddress),
        _info('Account type', c.accountType),
        _info('SLA hours', c.slaHours?.toString()),
        _info('GPS', c.locationCoords),
        _info('Code', c.code),
        _info('Notes', c.notes),
        _info('Status', c.isActive ? 'Active' : 'Inactive'),
      ],
    );
  }

  Widget _info(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(label,
            style: const TextStyle(
              fontSize: 12,
              color: GlossColors.muted,
            )),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: GlossColors.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SystemsTab extends StatelessWidget {
  const _SystemsTab({
    required this.clientId,
    required this.systemsAsync,
    required this.onRefresh,
  });

  final String clientId;
  final AsyncValue systemsAsync;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: systemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e'),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 48),
                Center(
                  child: Text(
                    'No systems on this client yet.\nUse Attach system.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GlossColors.muted),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = items[i];
              return Card(
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Text(
                    s.subtitle.isEmpty ? s.status : s.subtitle,
                    style: const TextStyle(color: GlossColors.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/systems/${s.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
