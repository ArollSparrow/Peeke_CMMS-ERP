import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import 'org_providers.dart';

class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(myOrganizationsProvider);
    final active = ref.watch(activeOrganizationProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(active?.name ?? 'Peeke'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orgs) {
          if (orgs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No organization yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a tenant organization to start using the platform.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GlossColors.muted),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.push('/org/create'),
                      child: const Text('Create organization'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Signed in as ${user?.email ?? '—'}',
                style: const TextStyle(color: GlossColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                active == null
                    ? 'Select an organization'
                    : 'Active: ${active.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Master data',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: GlossColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Clients'),
                  subtitle: const Text('Customer organizations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/clients'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('Systems'),
                  subtitle: const Text('Assets (generators, inverters, …)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/systems'),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Organizations',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: GlossColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              ...orgs.map(
                (o) => Card(
                  child: ListTile(
                    title: Text(o.name),
                    subtitle: Text('${o.slug} · ${o.status}'),
                    selected: active?.id == o.id,
                    onTap: () {
                      ref.read(activeOrganizationIdProvider.notifier).state =
                          o.id;
                    },
                    trailing: active?.id == o.id
                        ? const Icon(Icons.check_circle,
                            color: GlossColors.accent)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.push('/org/create'),
                child: const Text('Create another organization'),
              ),
            ],
          );
        },
      ),
    );
  }
}
