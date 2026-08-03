import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../org/org_providers.dart';
import 'payment_models.dart';
import 'payment_providers.dart';

class PaymentsHubScreen extends ConsumerWidget {
  const PaymentsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(paymentSettingsProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                settings?.isConfigured == true ? Icons.check_circle : Icons.warning_amber_outlined,
                color: settings?.isConfigured == true
                    ? const Color(0xFF16A34A)
                    : GlossColors.muted,
              ),
              title: Text(settings?.statusLabel ?? 'Not configured'),
              subtitle: Text(
                settings == null
                    ? 'Connect your own Paystack account'
                    : '${settings.provider} · ${settings.currency}'
                        '${settings.businessName != null ? ' · ${settings.businessName}' : ''}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _t(context, Icons.key_outlined, 'Payment credentials',
              'BYO Paystack public + secret keys', '/payments/settings'),
          _t(context, Icons.receipt_long_outlined, 'Transactions',
              'Payments logged against this org', '/payments/transactions'),
          const SizedBox(height: 16),
          const Text(
            'Peeke is the platform only. Each organization uses its own '
            'Paystack (or Stripe) merchant account. Customer charges settle '
            'to the tenant — not to Peeke.',
            style: TextStyle(color: GlossColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _t(BuildContext c, IconData i, String t, String s, String r) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(i, color: GlossColors.accent),
          title: Text(t),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => c.push(r),
        ),
      );
}

class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  final _publicKey = TextEditingController();
  final _secretKey = TextEditingController();
  final _webhook = TextEditingController();
  final _business = TextEditingController();
  final _notes = TextEditingController();
  String _currency = 'KES';
  bool _isLive = false;
  bool _isEnabled = false;
  bool _loading = false;
  bool _hydrated = false;
  bool _showSecret = false;
  String? _existingSecretMasked;

  @override
  void dispose() {
    _publicKey.dispose();
    _secretKey.dispose();
    _webhook.dispose();
    _business.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(PaymentSettings s) {
    if (_hydrated) return;
    _hydrated = true;
    _publicKey.text = s.publicKey ?? '';
    _business.text = s.businessName ?? '';
    _notes.text = s.notes ?? '';
    _currency = s.currency;
    _isLive = s.isLive;
    _isEnabled = s.isEnabled;
    _existingSecretMasked = PaymentSettings.maskKey(s.secretKey);
    // secret field left blank — only send if user types a new value
  }

  Future<void> _save() async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(paymentRepositoryProvider).upsertSettings(
            organizationId: org.id,
            isLive: _isLive,
            isEnabled: _isEnabled,
            publicKey: _publicKey.text,
            secretKey: _secretKey.text.trim().isEmpty ? null : _secretKey.text,
            webhookSecret: _webhook.text.trim().isEmpty ? null : _webhook.text,
            currency: _currency,
            businessName: _business.text,
            notes: _notes.text,
            touchVerified: _publicKey.text.trim().isNotEmpty,
          );
      ref.invalidate(paymentSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment settings saved')),
      );
      setState(() {
        _hydrated = false;
        _secretKey.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paymentSettingsProvider);
    async.whenData((s) {
      if (s != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hydrate(s));
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Payment credentials')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Text(
            'Use keys from your own Paystack dashboard. '
            'Test keys start with pk_test_ / sk_test_; live keys with pk_live_ / sk_live_.',
            style: TextStyle(color: GlossColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable payments'),
            subtitle: const Text('Allow collecting customer payments with these keys'),
            value: _isEnabled,
            onChanged: (v) => setState(() => _isEnabled = v),
          ),
          SwitchListTile(
            title: const Text('Live mode'),
            subtitle: Text(_isLive ? 'Using live merchant keys' : 'Using test keys'),
            value: _isLive,
            onChanged: (v) => setState(() => _isLive = v),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _business,
            decoration: const InputDecoration(labelText: 'Business name (optional)'),
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
              labelText: _existingSecretMasked != null && _existingSecretMasked != 'Not set'
                  ? 'Secret key (leave blank to keep current)'
                  : 'Secret key *',
              hintText: _existingSecretMasked ?? 'sk_test_… or sk_live_…',
              helperText: _existingSecretMasked != null && _existingSecretMasked != 'Not set'
                  ? 'Stored: $_existingSecretMasked'
                  : null,
              suffixIcon: IconButton(
                icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showSecret = !_showSecret),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _webhook,
            decoration: const InputDecoration(
              labelText: 'Webhook secret (optional)',
              hintText: 'For future webhook verification',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text(
            'Security: secret keys are only writable by organization admins. '
            'Prefer verifying charges via a server-side function in production; '
            'never commit keys to git.',
            style: TextStyle(color: GlossColors.muted, fontSize: 12),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save credentials'),
          ),
        ),
      ),
    );
  }
}

class PaymentTransactionsScreen extends ConsumerWidget {
  const PaymentTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentTransactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentTransactionsProvider);
          await ref.read(paymentTransactionsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 48),
                Center(child: Text('No transactions yet')),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'When you collect payments with your Paystack keys, '
                    'records will appear here.',
                    textAlign: TextAlign.center,
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
                final t = items[i];
                return Card(
                  child: ListTile(
                    title: Text('${t.currency} ${t.amount.toStringAsFixed(2)}'),
                    subtitle: Text(
                      [
                        t.reference,
                        if (t.customerEmail != null) t.customerEmail!,
                        if (t.description != null) t.description!,
                      ].join(' · '),
                      style: const TextStyle(color: GlossColors.muted, fontSize: 12),
                    ),
                    trailing: Chip(
                      label: Text(t.status, style: const TextStyle(fontSize: 11)),
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
}
