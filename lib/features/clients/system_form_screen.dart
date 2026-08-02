import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../org/org_providers.dart';
import 'client_models.dart';
import 'client_providers.dart';

class SystemFormScreen extends ConsumerStatefulWidget {
  const SystemFormScreen({
    super.key,
    this.systemId,
    this.preselectedClientId,
  });

  final String? systemId;
  final String? preselectedClientId;

  bool get isEdit => systemId != null;

  @override
  ConsumerState<SystemFormScreen> createState() => _SystemFormScreenState();
}

class _SystemFormScreenState extends ConsumerState<SystemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _serial = TextEditingController();
  final _model = TextEditingController();
  final _capacity = TextEditingController();
  final _barcode = TextEditingController();
  final _fuel = TextEditingController();
  final _hourMeter = TextEditingController();
  final _energyMeter = TextEditingController();
  final _otherType = TextEditingController();
  final _notes = TextEditingController();

  Client? _client;
  String? _type = 'Generator';
  String? _unit = 'kW';
  DateTime? _installDate = DateTime.now();
  DateTime? _regDate = DateTime.now();
  bool _loading = false;
  bool _hydrated = false;
  bool _clientsLoaded = false;

  static const _types = ['Generator', 'PV Inverter', 'Pump Inverter', 'Other'];
  static const _units = ['kW', 'kVA'];

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    _model.dispose();
    _capacity.dispose();
    _barcode.dispose();
    _fuel.dispose();
    _hourMeter.dispose();
    _energyMeter.dispose();
    _otherType.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(AssetSystem s, List<Client> clients) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = s.name;
    _serial.text = s.serialNumber ?? '';
    _model.text = s.model ?? '';
    _capacity.text = s.capacity?.toString() ?? '';
    _barcode.text = s.barcode ?? '';
    _fuel.text = s.fuelTankCapacity?.toString() ?? '';
    _hourMeter.text = s.initialHourMeter?.toString() ?? '';
    _energyMeter.text = s.initialEnergyMeter?.toString() ?? '';
    _notes.text = s.notes ?? '';
    _unit = s.capacityUnit ?? 'kW';
    _installDate = s.installationDate ?? DateTime.now();
    _regDate = s.registrationDate ?? DateTime.now();
    if (s.type != null && _types.contains(s.type)) {
      _type = s.type;
    } else if (s.type != null) {
      _type = 'Other';
      _otherType.text = s.type!;
    }
    if (s.clientId != null) {
      _client = clients.cast<Client?>().firstWhere(
            (c) => c?.id == s.clientId,
            orElse: () => null,
          );
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) onPicked(d);
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    if (_client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a client — systems must be linked')),
      );
      return;
    }

    final resolvedType =
        _type == 'Other' ? _otherType.text.trim() : (_type ?? '');
    if (resolvedType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System type is required')),
      );
      return;
    }

    final displayName = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : [
            resolvedType,
            if (_serial.text.trim().isNotEmpty) _serial.text.trim(),
            if (_model.text.trim().isNotEmpty) _model.text.trim(),
          ].join(' ');

    setState(() => _loading = true);
    try {
      final repo = ref.read(systemRepositoryProvider);
      late AssetSystem saved;

      if (widget.isEdit) {
        saved = await repo.update(widget.systemId!, {
          'name': displayName,
          'client_id': _client!.id,
          'client_name': _client!.name,
          'client_location': _client!.location,
          'client_site': _client!.siteName,
          'type': resolvedType,
          'system_type': resolvedType,
          'model': _model.text.trim().isEmpty ? null : _model.text.trim(),
          'serial_number':
              _serial.text.trim().isEmpty ? null : _serial.text.trim(),
          'capacity': double.tryParse(_capacity.text.trim()),
          'capacity_unit': _unit,
          'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
          'installation_date': _installDate?.toIso8601String().split('T').first,
          'registration_date': _regDate?.toIso8601String().split('T').first,
          'fuel_tank_capacity': double.tryParse(_fuel.text.trim()),
          'initial_hour_meter': double.tryParse(_hourMeter.text.trim()),
          'initial_energy_meter': double.tryParse(_energyMeter.text.trim()),
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        });
      } else {
        saved = await repo.create(
          organizationId: org.id,
          name: displayName,
          clientId: _client!.id,
          clientName: _client!.name,
          clientLocation: _client!.location,
          clientSite: _client!.siteName,
          type: resolvedType,
          model: _model.text,
          serialNumber: _serial.text,
          capacity: double.tryParse(_capacity.text.trim()),
          capacityUnit: _unit,
          barcode: _barcode.text,
          installationDate: _installDate,
          registrationDate: _regDate,
          fuelTankCapacity: double.tryParse(_fuel.text.trim()),
          initialHourMeter: double.tryParse(_hourMeter.text.trim()),
          initialEnergyMeter: double.tryParse(_energyMeter.text.trim()),
          notes: _notes.text,
        );
      }

      ref.invalidate(systemsListProvider);
      ref.invalidate(systemByIdProvider(saved.id));
      ref.invalidate(systemsByClientProvider(_client!.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'System updated' : 'System saved'),
        ),
      );
      context.go('/systems/${saved.id}');
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
    final org = ref.watch(activeOrganizationProvider);
    final clientsAsync = ref.watch(clientsListProvider);

    clientsAsync.whenData((clients) {
      if (!_clientsLoaded && clients.isNotEmpty) {
        _clientsLoaded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.preselectedClientId != null) {
            final match = clients.cast<Client?>().firstWhere(
                  (c) => c?.id == widget.preselectedClientId,
                  orElse: () => null,
                );
            if (match != null) setState(() => _client = match);
          } else if (_client == null && !widget.isEdit) {
            // leave unset until user picks
          }
        });
      }
    });

    if (widget.isEdit) {
      final sysAsync = ref.watch(systemByIdProvider(widget.systemId!));
      sysAsync.whenData((s) {
        clientsAsync.whenData((clients) {
          if (s != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hydrate(s, clients));
            });
          }
        });
      });
    }

    final isGenerator = _type == 'Generator';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit system' : 'Register system'),
      ),
      body: org == null
          ? const Center(child: Text('Select an organization first'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  _section('Client link'),
                  clientsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Clients error: $e'),
                    data: (clients) {
                      if (clients.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No clients yet. Register a client first.',
                              style: TextStyle(color: GlossColors.danger),
                            ),
                            TextButton(
                              onPressed: () => context.push('/clients/new'),
                              child: const Text('Register client'),
                            ),
                          ],
                        );
                      }
                      return DropdownButtonFormField<Client>(
                        value: _client != null &&
                                clients.any((c) => c.id == _client!.id)
                            ? clients.firstWhere((c) => c.id == _client!.id)
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Client *',
                        ),
                        items: clients
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.displaySite,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (c) => setState(() => _client = c),
                        validator: (v) => v == null ? 'Required' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _section('System identity'),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Type *'),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  if (_type == 'Other') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otherType,
                      decoration: const InputDecoration(
                        labelText: 'Specify type *',
                      ),
                      validator: (v) => (_type == 'Other' &&
                              (v == null || v.trim().isEmpty))
                          ? 'Required'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      hintText: 'Defaults from type + serial/model',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serial,
                    decoration: const InputDecoration(
                      labelText: 'Serial number *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _model,
                    decoration: const InputDecoration(labelText: 'Model *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barcode,
                    decoration: const InputDecoration(
                      labelText: 'Barcode',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _capacity,
                          decoration: const InputDecoration(
                            labelText: 'Capacity *',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(v.trim()) == null) {
                              return 'Numeric';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: _unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: _units
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (u) => setState(() => _unit = u),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Installation date'),
                    subtitle: Text(_fmt(_installDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(
                      current: _installDate,
                      onPicked: (d) => setState(() => _installDate = d),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Registration date'),
                    subtitle: Text(_fmt(_regDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(
                      current: _regDate,
                      onPicked: (d) => setState(() => _regDate = d),
                    ),
                  ),
                  if (isGenerator) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fuel,
                      decoration: const InputDecoration(
                        labelText: 'Fuel tank capacity (L)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _section('Baseline readings'),
                  TextFormField(
                    controller: _hourMeter,
                    decoration: const InputDecoration(
                      labelText: 'Initial hour meter (Hrs)',
                      hintText: '0 if brand new',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _energyMeter,
                    decoration: const InputDecoration(
                      labelText: 'Initial energy meter (kWHrs)',
                      hintText: '0 if brand new',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
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
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEdit ? 'Update system' : 'Save system'),
                ),
              ),
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
