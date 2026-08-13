import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'platform_models.dart';
import 'platform_providers.dart';

class PostAuthGateScreen extends ConsumerWidget {
  const PostAuthGateScreen({super.key});

  Future<void> _acceptInvites(WidgetRef ref) async {
    try {
      await ref.read(supabaseClientProvider).rpc('accept_pending_org_invites');
    } catch (_) {}
    ref.invalidate(myOrganizationsProvider);
    ref.invalidate(myPendingInviteCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminAsync = ref.watch(isPlatformAdminProvider);

    return adminAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _acceptInvites(ref);
          if (context.mounted) context.go('/home');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      data: (isAdmin) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!isAdmin) await _acceptInvites(ref);
          if (!context.mounted) return;
          context.go(isAdmin ? '/platform' : '/home');
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class PlatformHomeScreen extends ConsumerWidget {
  const PlatformHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(platformTenantsProvider);
    final pay = ref.watch(platformPaymentSettingsProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);

    final tenantCount = tenants.valueOrNull?.length;
    final pendingCount = tenants.valueOrNull
        ?.where((t) => t.status == 'pending')
        .length;
    final activeCount = tenants.valueOrNull
        ?.where((t) => t.status == 'active' || t.status == 'testing')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peeke Platform'),
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformTenantsProvider);
          ref.invalidate(platformPaymentSettingsProvider);
          ref.invalidate(platformSubscriptionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text(
              'Platform owner',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GlossColors.navy),
            ),
            const SizedBox(height: 4),
            Text(user?.email ?? '',
                style: const TextStyle(color: GlossColors.teal)),
            const SizedBox(height: 8),
            const Text(
              'Hard gate: new organisations wait for review. '
              'Approve, open a test window, reject, or suspend from Tenants.',
              style: TextStyle(color: GlossColors.teal, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _Kpi(
                  label: 'Pending',
                  value: pendingCount?.toString() ?? '…',
                  icon: Icons.hourglass_empty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  label: 'Active / test',
                  value: activeCount?.toString() ?? '…',
                  icon: Icons.verified_outlined,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _Kpi(
              label: 'All tenants',
              value: tenantCount?.toString() ?? '…',
              icon: Icons.apartment,
            ),
            const SizedBox(height: 24),
            const _Label('Platform console'),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.apartment,
              title: 'Tenants',
              subtitle: 'Review · approve · test window',
              badge: pendingCount != null && pendingCount > 0
                  ? '$pendingCount'
                  : tenantCount?.toString(),
              onTap: () => context.push('/platform/tenants'),
            ),
            _Tile(
              icon: Icons.card_membership_outlined,
              title: 'Subscriptions',
              subtitle: 'Plans & billing status per tenant',
              onTap: () => context.push('/platform/subscriptions'),
            ),
            _Tile(
              icon: Icons.key_outlined,
              title: 'Platform Paystack',
              subtitle: pay?.isConfigured == true
                  ? (pay!.isLive
                      ? 'Live keys configured'
                      : 'Test keys configured')
                  : 'Keys for collecting tenant subscriptions',
              badge: pay?.isEnabled == true ? 'On' : 'Setup',
              onTap: () => context.push('/platform/payments'),
            ),
          ],
        ),
      ),
    );
  }
}

class PlatformTenantsScreen extends ConsumerWidget {
  const PlatformTenantsScreen({super.key});

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    TenantOrgSummary t,
    String action,
  ) async {
    try {
      await ref.read(platformRepositoryProvider).reviewOrganization(
            organizationId: t.id,
            action: action,
            testingDays: 14,
          );
      ref.invalidate(platformTenantsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.name}: $action')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(platformTenantsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tenant organisations yet.\n\n'
                  'Applicants confirm email, submit an organisation, '
                  'and wait here for review.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          // Pending first
          final sorted = [...items]..sort((a, b) {
              int rank(String s) {
                switch (s) {
                  case 'pending':
                    return 0;
                  case 'testing':
                    return 1;
                  case 'active':
                    return 2;
                  default:
                    return 3;
                }
              }

              return rank(a.status).compareTo(rank(b.status));
            });

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = sorted[i];
              return Card(
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    [
                      t.slug,
                      if (t.planName != null) t.planName!,
                      if (t.subscriptionStatus != null) t.subscriptionStatus!,
                    ].join(' · '),
                    style: const TextStyle(color: GlossColors.teal, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label:
                            Text(t.status, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) =>
                            _review(context, ref, t, action),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'approve', child: Text('Approve (active)')),
                          PopupMenuItem(
                              value: 'test_window',
                              child: Text('Test window (14 days)')),
                          PopupMenuItem(
                              value: 'reject', child: Text('Reject')),
                          PopupMenuItem(
                              value: 'suspend', child: Text('Suspend')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => context.push(
                    '/platform/subscriptions?orgId=${t.id}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PlatformSubscriptionsScreen extends ConsumerStatefulWidget {
  const PlatformSubscriptionsScreen({super.key, this.preselectedOrgId});

  final String? preselectedOrgId;

  @override
  ConsumerState<PlatformSubscriptionsScreen> createState() =>
      _PlatformSubscriptionsScreenState();
}

class _PlatformSubscriptionsScreenState
    extends ConsumerState<PlatformSubscriptionsScreen> {
  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(platformSubscriptionsProvider);
    final tenants = ref.watch(platformTenantsProvider).valueOrNull ?? [];
    final plans = ref.watch(subscriptionPlansProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: tenants.isEmpty
            ? null
            : () => _assignDialog(context, tenants, plans),
        icon: const Icon(Icons.add),
        label: const Text('Assign plan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformSubscriptionsProvider);
          ref.invalidate(platformTenantsProvider);
        },
        child: subs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
                padding: const EdgeInsets.all(24),
                child: Text(friendlyError(e)))
          ]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 48),
                Center(child: Text('No subscriptions assigned yet')),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = items[i];
                return Card(
                  child: ListTile(
                    title: Text(s.organizationName ?? s.organizationId),
                    subtitle: Text(
                      [
                        s.planName ?? 'No plan',
                        s.status,
                        if (s.amount != null)
                          '${s.currency} ${s.amount!.toStringAsFixed(0)}/${s.billingInterval}',
                      ].join(' · '),
                      style:
                          const TextStyle(color: GlossColors.teal, fontSize: 12),
                    ),
                    trailing: Chip(
                      label: Text(s.status, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _assignDialog(
    BuildContext context,
    List<TenantOrgSummary> tenants,
    List<SubscriptionPlan> plans,
  ) async {
    String? orgId = widget.preselectedOrgId ??
        (tenants.isNotEmpty ? tenants.first.id : null);
    String? planId = plans.isNotEmpty ? plans.first.id : null;
    String status = 'trialing';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Assign subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: orgId,
                decoration: const InputDecoration(labelText: 'Tenant'),
                items: tenants
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => orgId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: planId,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: plans
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} · ${p.priceLabel}'),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => planId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  'trialing',
                  'active',
                  'past_due',
                  'cancelled',
                  'expired'
                ]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setLocal(() => status = v ?? 'trialing'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true || orgId == null) return;
    SubscriptionPlan? plan;
    for (final p in plans) {
      if (p.id == planId) {
        plan = p;
        break;
      }
    }
    try {
      await ref.read(platformRepositoryProvider).upsertSubscription(
            organizationId: orgId!,
            planId: planId,
            status: status,
            amount: plan?.amount,
            currency: plan?.currency ?? 'KES',
            billingInterval: plan?.interval ?? 'month',
          );
      ref.invalidate(platformSubscriptionsProvider);
      ref.invalidate(platformTenantsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class PlatformPaymentSettingsScreen extends ConsumerStatefulWidget {
  const PlatformPaymentSettingsScreen({super.key});

  @override
  ConsumerState<PlatformPaymentSettingsScreen> createState() =>
      _PlatformPaymentSettingsScreenState();
}

class _PlatformPaymentSettingsScreenState
    extends ConsumerState<PlatformPaymentSettingsScreen> {
  final _publicKey = TextEditingController();
  final _secretKey = TextEditingController();
  final _business = TextEditingController();
  String _currency = 'KES';
  bool _isLive = false;
  bool _isEnabled = false;
  bool _loading = false;
  bool _hydrated = false;
  bool _showSecret = false;
  bool _hasSecretKey = false;

  @override
  void dispose() {
    _publicKey.dispose();
    _secretKey.dispose();
    _business.dispose();
    super.dispose();
  }

  void _hydrate(PlatformPaymentSettings s) {
    if (_hydrated) return;
    _hydrated = true;
    _publicKey.text = s.publicKey ?? '';
    _business.text = s.businessName ?? 'Peeke Platform';
    _currency = s.currency;
    _isLive = s.isLive;
    _isEnabled = s.isEnabled;
    _hasSecretKey = s.hasSecretKey;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(platformRepositoryProvider).upsertPlatformPaymentSettings(
            isLive: _isLive,
            isEnabled: _isEnabled,
            publicKey: _publicKey.text,
            currency: _currency,
            businessName: _business.text,
          );

      final secret = _secretKey.text.trim();
      if (secret.isNotEmpty) {
        await ref
            .read(platformRepositoryProvider)
            .setPlatformSecrets(secretKey: secret);
      }

      ref.invalidate(platformPaymentSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Platform Paystack keys saved')),
      );
      setState(() {
        _hydrated = false;
        _secretKey.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(platformPaymentSettingsProvider);
    async.whenData((s) {
      if (s != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hydrate(s));
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Platform Paystack')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Text(
            'These are Peeke’s merchant keys — used only to collect '
            'subscription fees from tenant organizations. '
            'Secret keys are stored server-side and never returned to the app.',
            style: TextStyle(color: GlossColors.teal, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable subscription collection'),
            value: _isEnabled,
            onChanged: (v) => setState(() => _isEnabled = v),
          ),
          SwitchListTile(
            title: const Text('Live mode'),
            value: _isLive,
            onChanged: (v) => setState(() => _isLive = v),
          ),
          TextFormField(
            controller: _business,
            decoration: const InputDecoration(labelText: 'Business name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: const ['KES', 'NGN', 'GHS', 'ZAR', 'USD']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _currency = v ?? 'KES'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _publicKey,
            decoration: const InputDecoration(
              labelText: 'Public key *',
              hintText: 'pk_test_… or pk_live_…',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _secretKey,
            obscureText: !_showSecret,
            decoration: InputDecoration(
              labelText: _hasSecretKey
                  ? 'Secret key (leave blank to keep)'
                  : 'Secret key *',
              helperText: _hasSecretKey
                  ? 'A secret is already stored on the server'
                  : 'Never returned to the app after save',
              suffixIcon: IconButton(
                icon: Icon(
                    _showSecret ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showSecret = !_showSecret),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save platform keys'),
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlossColors.sky,
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
          Text(label,
              style: const TextStyle(fontSize: 12, color: GlossColors.teal)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: GlossColors.teal,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: GlossColors.teal),
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
                  color: GlossColors.sky,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style:
                        const TextStyle(fontSize: 12, color: GlossColors.navy)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
