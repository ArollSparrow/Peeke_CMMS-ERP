import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../clients/client_providers.dart';
import 'org_providers.dart';

class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(myOrganizationsProvider);
    final active = ref.watch(activeOrganizationProvider);
    final user = ref.watch(currentUserProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    final systemsAsync = ref.watch(systemsListProvider);

    final clientCount = clientsAsync.valueOrNull?.length;
    final systemCount = systemsAsync.valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peeke CMMS-ERP'),
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
            return _EmptyOrg(onCreate: () => context.push('/org/create'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myOrganizationsProvider);
              ref.invalidate(clientsListProvider);
              ref.invalidate(systemsListProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  active?.name ?? 'Organization',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: GlossColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: GlossColors.muted),
                ),
                if (active != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Slug · ${active.slug}',
                    style: const TextStyle(
                      color: GlossColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'Clients',
                        value: clientCount?.toString() ?? '…',
                        icon: Icons.business_outlined,
                        onTap: () => context.push('/clients'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        label: 'Systems',
                        value: systemCount?.toString() ?? '…',
                        icon: Icons.memory_outlined,
                        onTap: () => context.push('/systems'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'Organizations',
                        value: '${orgs.length}',
                        icon: Icons.apartment_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: _KpiCard(
                        label: 'Role',
                        value: 'Owner',
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Modules'),
                const SizedBox(height: 8),
                _ModuleTile(
                  icon: Icons.app_registration_outlined,
                  title: 'Registration',
                  subtitle: 'Clients → systems (full module)',
                  badge: 'Live',
                  onTap: () => context.push('/registration'),
                ),
                _ModuleTile(
                  icon: Icons.business,
                  title: 'Clients',
                  subtitle: 'Profiles, sites, SLA',
                  badge: clientCount == null
                      ? null
                      : (clientCount == 0 ? 'Empty' : '$clientCount'),
                  onTap: () => context.push('/clients'),
                ),
                _ModuleTile(
                  icon: Icons.memory,
                  title: 'Systems',
                  subtitle: 'Assets linked to clients',
                  badge: systemCount == null
                      ? null
                      : (systemCount == 0 ? 'Empty' : '$systemCount'),
                  onTap: () => context.push('/systems'),
                ),
                const _ModuleTile(
                  icon: Icons.handyman_outlined,
                  title: 'Work orders',
                  subtitle: 'Phase 2 — not started',
                  enabled: false,
                ),
                const _ModuleTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventory',
                  subtitle: 'Phase 3 — not started',
                  enabled: false,
                ),
                const _ModuleTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Procurement',
                  subtitle: 'Phase 4 — not started',
                  enabled: false,
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Build progress'),
                const SizedBox(height: 8),
                const _ProgressCard(
                  items: [
                    _ProgressItem(
                      done: true,
                      title: 'Phase 0 — Foundation',
                      detail: 'Auth, org, RLS, home shell',
                    ),
                    _ProgressItem(
                      done: true,
                      title: 'Phase 1 — Registration module',
                      detail:
                          'Client/system CRUD, link, detail, attach flow',
                    ),
                    _ProgressItem(
                      done: false,
                      title: 'Phase 1 — Contracts (optional)',
                      detail: 'Client contracts screen later',
                    ),
                    _ProgressItem(
                      done: false,
                      title: 'Phase 2 — Work loop',
                      detail: 'Requests → work orders',
                    ),
                    _ProgressItem(
                      done: false,
                      title: 'Phase 7 — BYO payments',
                      detail: 'Tenant Paystack credentials',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Your organizations'),
                const SizedBox(height: 8),
                ...orgs.map(
                  (o) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(o.name),
                      subtitle: Text('${o.slug} · ${o.status}'),
                      selected: active?.id == o.id,
                      onTap: () {
                        ref
                            .read(activeOrganizationIdProvider.notifier)
                            .state = o.id;
                      },
                      trailing: active?.id == o.id
                          ? const Icon(Icons.check_circle,
                              color: GlossColors.accent)
                          : null,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/org/create'),
                  child: const Text('Create another organization'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyOrg extends StatelessWidget {
  const _EmptyOrg({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment, size: 48, color: GlossColors.muted),
            const SizedBox(height: 16),
            const Text(
              'No organization yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your organization is the tenant boundary for data, users, and payments.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GlossColors.muted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onCreate,
              child: const Text('Create organization'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: GlossColors.muted,
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GlossColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GlossColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: GlossColors.accent),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GlossColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: GlossColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: enabled ? GlossColors.accent : GlossColors.muted,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GlossColors.pageBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GlossColors.muted,
                  ),
                ),
              ),
            if (enabled) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ],
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _ProgressItem {
  const _ProgressItem({
    required this.done,
    required this.title,
    required this.detail,
  });
  final bool done;
  final String title;
  final String detail;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.items});
  final List<_ProgressItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final item in items)
              ListTile(
                dense: true,
                leading: Icon(
                  item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: item.done ? const Color(0xFF16A34A) : GlossColors.muted,
                  size: 22,
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: item.done ? GlossColors.ink : GlossColors.muted,
                  ),
                ),
                subtitle: Text(item.detail),
              ),
          ],
        ),
      ),
    );
  }
}
