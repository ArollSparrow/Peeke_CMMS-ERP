import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:powersync/powersync.dart' show SyncStatus;

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../../infra/sync/powersync_database.dart';
import '../../infra/sync/sync_providers.dart';
import '../auth/auth_providers.dart';
import '../clients/client_providers.dart';
import '../inventory/inventory_providers.dart';
import '../maintenance/maintenance_providers.dart';
import '../operations/operations_providers.dart';
import '../payments/payment_providers.dart';
import '../procurement/procurement_providers.dart';
import '../work/work_providers.dart';
import 'org_providers.dart';
import 'org_status_screen.dart';

class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Opt-in: only connects when POWERSYNC_URL is set at build time.
    ref.watch(powerSyncConnectionProvider);
    final syncConfigured = ref.watch(powerSyncConfiguredProvider);
    final syncStatus = ref.watch(powerSyncStatusProvider).valueOrNull;

    final orgsAsync = ref.watch(myOrganizationsProvider);
    final active = ref.watch(activeOrganizationProvider);
    final user = ref.watch(currentUserProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    final openWo = ref.watch(openWorkOrdersCountProvider).valueOrNull;
    final lowStock = ref.watch(lowStockCountProvider).valueOrNull;
    final partsCount = ref.watch(partsCountProvider).valueOrNull;
    final openPo = ref.watch(openPoCountProvider).valueOrNull;
    final duePm = ref.watch(duePmCountProvider).valueOrNull;
    final opsToday = ref.watch(opsTodayCountProvider).valueOrNull;
    final paySettings = ref.watch(paymentSettingsProvider).valueOrNull;
    final pendingInvites =
        ref.watch(myPendingInviteCountProvider).valueOrNull ?? 0;
    final isInvited = ref.watch(isInvitedUserProvider);
    final inviteLanding = ref.watch(teamInviteLandingProvider);

    final clientCount = clientsAsync.valueOrNull?.length;
    final payBadge = paySettings == null
        ? 'Setup'
        : (paySettings.isConfigured && paySettings.isEnabled
            ? paySettings.statusLabel
            : 'Setup');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peeke CMMS-ERP'),
        actions: [
          if (syncConfigured)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Tooltip(
                  message: _syncTooltip(syncStatus),
                  child: Icon(
                    _syncIcon(syncStatus),
                    size: 20,
                    color: _syncColor(syncStatus),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await PeekePowerSync.disconnectAndClear();
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (orgs) {
          if (orgs.isEmpty) {
            final blockTenantCreate =
                pendingInvites > 0 || isInvited || inviteLanding;
            return _EmptyOrg(
              blockTenantCreate: blockTenantCreate,
              pendingInvites: pendingInvites,
              onCreate: () => context.push('/org/create'),
              onRetryJoin: () async {
                try {
                  await ref
                      .read(supabaseClientProvider)
                      .rpc('accept_pending_org_invites');
                } catch (_) {}
                ref.invalidate(myOrganizationsProvider);
                ref.invalidate(myPendingInviteCountProvider);
              },
            );
          }

          if (active != null && !active.hasProductAccess) {
            return const OrgStatusScreen();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myOrganizationsProvider);
              ref.invalidate(clientsListProvider);
              ref.invalidate(systemsListProvider);
              ref.invalidate(openWorkOrdersCountProvider);
              ref.invalidate(lowStockCountProvider);
              ref.invalidate(partsCountProvider);
              ref.invalidate(openPoCountProvider);
              ref.invalidate(duePmCountProvider);
              ref.invalidate(opsTodayCountProvider);
              ref.invalidate(paymentSettingsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(active?.name ?? 'Organization',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GlossColors.navy)),
                const SizedBox(height: 4),
                Text(user?.email ?? '',
                    style: const TextStyle(color: GlossColors.teal)),
                if (active != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      'Slug · ${active.slug}${active.status == 'testing' ? ' · test window' : ''}',
                      style: const TextStyle(
                          color: GlossColors.teal, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'Open WOs',
                      value: openWo?.toString() ?? '…',
                      icon: Icons.handyman_outlined,
                      onTap: () => context.push('/work/orders'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      label: 'Ops today',
                      value: opsToday?.toString() ?? '…',
                      icon: Icons.play_circle_outline,
                      onTap: () => context.push('/operations/records'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'PM due',
                      value: duePm?.toString() ?? '…',
                      icon: Icons.event_repeat_outlined,
                      onTap: () => context.push('/maintenance/plans'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      label: 'Low stock',
                      value: lowStock?.toString() ?? '…',
                      icon: Icons.warning_amber_outlined,
                      onTap: () => context.push('/inventory/parts?low=1'),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                const _SectionLabel('Modules'),
                const SizedBox(height: 8),
                _ModuleTile(
                  icon: Icons.group_outlined,
                  title: 'Team',
                  subtitle: 'Members & invites',
                  badge: 'Live',
                  onTap: () => context.push('/org/team'),
                ),
                _ModuleTile(
                  icon: Icons.app_registration_outlined,
                  title: 'Registration',
                  subtitle: 'Clients → systems',
                  badge: 'Live',
                  onTap: () => context.push('/registration'),
                ),
                _ModuleTile(
                  icon: Icons.handyman_outlined,
                  title: 'Work loop',
                  subtitle: 'Requests → work orders',
                  badge: openWo == null ? 'Live' : '$openWo open',
                  onTap: () => context.push('/work'),
                ),
                _ModuleTile(
                  icon: Icons.play_circle_outline,
                  title: 'Operations',
                  subtitle: 'Start/stop, fuel, breakdown',
                  badge: opsToday == null ? 'Live' : '$opsToday today',
                  onTap: () => context.push('/operations'),
                ),
                _ModuleTile(
                  icon: Icons.event_repeat_outlined,
                  title: 'Maintenance',
                  subtitle: 'PM plans → jobs → history',
                  badge: duePm == null ? 'Live' : '$duePm due',
                  onTap: () => context.push('/maintenance'),
                ),
                _ModuleTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventory',
                  subtitle: 'Parts, receive, issue',
                  badge: partsCount == null ? 'Live' : '$partsCount',
                  onTap: () => context.push('/inventory'),
                ),
                _ModuleTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Procurement',
                  subtitle: 'Vendors → POs → receive',
                  badge: openPo == null ? 'Live' : '$openPo open',
                  onTap: () => context.push('/procurement'),
                ),
                _ModuleTile(
                  icon: Icons.payments_outlined,
                  title: 'Payments',
                  subtitle: 'BYO Paystack credentials',
                  badge: payBadge,
                  onTap: () => context.push('/payments'),
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
                const SizedBox(height: 24),
                const _SectionLabel('Your organizations'),
                const SizedBox(height: 8),
                ...orgs.map((o) => Card(
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
                                color: GlossColors.teal)
                            : null,
                      ),
                    )),
                if (!isInvited || orgs.isNotEmpty)
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

  static String _syncTooltip(SyncStatus? s) {
    if (s == null) return 'Local sync enabled (PowerSync)';
    if (s.anyError != null) {
      return s.connected
          ? 'Sync problem — check connection'
          : 'Offline — local data only';
    }
    if (s.connecting) return 'Connecting to sync…';
    if (!s.connected) return 'Offline — local data only';
    if (s.downloading || s.uploading) return 'Syncing…';
    if (s.hasSynced == true) return 'Synced';
    return 'Local sync enabled (PowerSync)';
  }

  static IconData _syncIcon(SyncStatus? s) {
    if (s == null) return Icons.cloud_sync_outlined;
    if (s.anyError != null) {
      return s.connected ? Icons.sync_problem : Icons.cloud_off;
    }
    if (s.connecting) return Icons.cloud_sync_outlined;
    if (!s.connected) return Icons.cloud_off;
    if (s.downloading || s.uploading) return Icons.sync;
    return Icons.cloud_done_outlined;
  }

  static Color _syncColor(SyncStatus? s) {
    if (s == null) return GlossColors.teal.withValues(alpha: 0.85);
    if (s.anyError != null) {
      return s.connected ? Colors.orange.shade700 : Colors.grey.shade600;
    }
    if (!s.connected) return Colors.grey.shade600;
    if (s.downloading || s.uploading) return GlossColors.teal;
    return GlossColors.teal.withValues(alpha: 0.9);
  }
}

class _EmptyOrg extends StatelessWidget {
  const _EmptyOrg({
    required this.onCreate,
    required this.onRetryJoin,
    this.blockTenantCreate = false,
    this.pendingInvites = 0,
  });

  final VoidCallback onCreate;
  final VoidCallback onRetryJoin;
  final bool blockTenantCreate;
  final int pendingInvites;

  @override
  Widget build(BuildContext context) {
    if (blockTenantCreate) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_add_outlined,
                  size: 48, color: GlossColors.teal),
              const SizedBox(height: 16),
              const Text(
                'Joining your team',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: GlossColors.navy),
              ),
              const SizedBox(height: 8),
              Text(
                pendingInvites > 0
                    ? 'You have a pending invitation. Tap below to join — '
                        'this account will not create a new tenant organization.'
                    : 'This account was invited to an organization. '
                        'Tap below to accept membership. '
                        'To start your own tenant, register with a different email.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GlossColors.teal),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetryJoin,
                child: const Text('Accept team invite'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment, size: 48, color: GlossColors.teal),
            const SizedBox(height: 16),
            const Text('No organization yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: GlossColors.navy)),
            const SizedBox(height: 8),
            const Text(
              'Create an organization to start using Peeke.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GlossColors.teal),
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
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: GlossColors.teal,
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GlossColors.sky,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GlossColors.teal),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: GlossColors.teal),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: GlossColors.navy)),
              const SizedBox(height: 2),
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: GlossColors.teal)),
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
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: GlossColors.navy),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: badge == null
            ? const Icon(Icons.chevron_right)
            : Text(badge!,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GlossColors.teal)),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
