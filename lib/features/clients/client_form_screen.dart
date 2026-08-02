import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../org/org_providers.dart';
import 'client_models.dart';
import 'client_providers.dart';

/// Full client registration / edit — production parity fields.
class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.clientId});

  final String? clientId;

  bool get isEdit => clientId != null;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _site = TextEditingController();
  final _location = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _billing = TextEditingController();
  final _manager = TextEditingController();
  final _coords = TextEditingController();
  final _code = TextEditingController();
  final _notes = TextEditingController();

  String _accountType = 'contract';
  int _slaHours = 24;
  bool _loading = false;
  bool _hydrated = false;

  static const _accountTypes = [
    ('contract', 'Contract'),
    ('ad_hoc', 'Ad Hoc'),
    ('warranty', 'Warranty'),
    ('internal', 'Internal'),
  ];

  static const _slaOptions = [4, 8, 24, 48, 72];

  @override
  void dispose() {
    _name.dispose();
    _site.dispose();
    _location.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _billing.dispose();
    _manager.dispose();
    _coords.dispose();
    _code.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(Client c) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = c.name;
    _site.text = c.siteName ?? '';
    _location.text = c.location ?? '';
    _contact.text = c.contact ?? '';
    _phone.text = c.phone ?? '';
    _email.text = c.email ?? '';
    _billing.text = c.billingAddress ?? '';
    _manager.text = c.accountManager ?? '';
    _coords.text = c.locationCoords ?? '';
    _code.text = c.code ?? '';
    _notes.text = c.notes ?? '';
    _accountType = c.accountType ?? 'contract';
    _slaHours = c.slaHours ?? 24;
  }

  Future<void> _save({bool attachSystem = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(clientRepositoryProvider);
      late Client saved;

      if (widget.isEdit) {
        saved = await repo.update(widget.clientId!, {
          'name': _name.text.trim(),
          'site_name': _site.text.trim().isEmpty ? null : _site.text.trim(),
          'location':
              _location.text.trim().isEmpty ? null : _location.text.trim(),
          'contact': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
          'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
          'billing_address':
              _billing.text.trim().isEmpty ? null : _billing.text.trim(),
          'account_manager':
              _manager.text.trim().isEmpty ? null : _manager.text.trim(),
          'location_coords':
              _coords.text.trim().isEmpty ? null : _coords.text.trim(),
          'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'account_type': _accountType,
          'sla_hours': _slaHours,
        });
      } else {
        saved = await repo.create(
          organizationId: org.id,
          name: _name.text.trim(),
          siteName: _site.text,
          location: _location.text,
          contact: _contact.text,
          phone: _phone.text,
          email: _email.text,
          billingAddress: _billing.text,
          accountManager: _manager.text,
          locationCoords: _coords.text,
          code: _code.text,
          notes: _notes.text,
          accountType: _accountType,
          slaHours: _slaHours,
        );
      }

      ref.invalidate(clientsListProvider);
      ref.invalidate(clientByIdProvider(saved.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Client updated' : 'Client saved'),
        ),
      );

      if (attachSystem) {
        context.push('/systems/new?clientId=${saved.id}');
      } else if (widget.isEdit) {
        context.pop();
      } else {
        context.go('/clients/${saved.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      final async = ref.watch(clientByIdProvider(widget.clientId!));
      async.whenData((c) {
        if (c != null) WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hydrate(c));
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit client' : 'Register client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _section('Client identity'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Client name *',
                hintText: 'Organisation or company',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _site,
                    decoration: const InputDecoration(
                      labelText: 'Site name *',
                      hintText: 'Branch / site',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Location *',
                      hintText: 'Town or area',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code',
                hintText: 'Optional short code',
              ),
            ),
            const SizedBox(height: 20),
            _section('Contact'),
            TextFormField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: 'Primary contact',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manager,
              decoration: const InputDecoration(
                labelText: 'Account manager',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _billing,
              decoration: const InputDecoration(
                labelText: 'Billing address',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            _section('Account & SLA'),
            const Text(
              'Account type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GlossColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in _accountTypes)
                  ChoiceChip(
                    label: Text(label),
                    selected: _accountType == value,
                    onSelected: (_) => setState(() => _accountType = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'SLA response time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GlossColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in _slaOptions)
                  ChoiceChip(
                    label: Text('$h hrs'),
                    selected: _slaHours == h,
                    onSelected: (_) => setState(() => _slaHours = h),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _section('Site location'),
            TextFormField(
              controller: _coords,
              decoration: const InputDecoration(
                labelText: 'GPS coordinates',
                hintText: 'Latitude, Longitude',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : () => _save(),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEdit ? 'Update' : 'Save'),
                ),
              ),
              if (!widget.isEdit) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _loading
                        ? null
                        : () => _save(attachSystem: true),
                    child: const Text('Save & attach'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: GlossColors.muted,
        ),
      ),
    );
  }
}
