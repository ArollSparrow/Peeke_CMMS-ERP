import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../clients/client_models.dart';
import '../clients/client_providers.dart';
import '../org/org_providers.dart';
import 'operations_models.dart';
import 'operations_providers.dart';

class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(opsTodayCountProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Operations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _t(context, Icons.play_circle_outline, 'Record operation',
              'Start / stop / single-mode logs', '/operations/record'),
          _t(context, Icons.local_gas_station_outlined, 'Log fueling',
              'Generator refuel event', '/operations/fueling'),
          _t(context, Icons.warning_amber_outlined, 'Report breakdown',
              'Open or resolve a breakdown', '/operations/breakdown'),
          _t(context, Icons.history, 'View records',
              today == null ? 'History by system' : '$today today', '/operations/records'),
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

class RecordOperationScreen extends ConsumerStatefulWidget {
  const RecordOperationScreen({super.key, this.fuelingOnly = false, this.breakdownOnly = false});
  final bool fuelingOnly;
  final bool breakdownOnly;

  @override
  ConsumerState<RecordOperationScreen> createState() => _RecordOperationScreenState();
}

class _RecordOperationScreenState extends ConsumerState<RecordOperationScreen> {
  String? _systemId;
  String? _opKey;
  String _opMode = 'start';
  final _attendant = TextEditingController();
  final _hourMeter = TextEditingController();
  final _powerMeter = TextEditingController();
  final _waterMeter = TextEditingController();
  final _fuelAdded = TextEditingController();
  final _faultCode = TextEditingController();
  final _cause = TextEditingController();
  final _resolution = TextEditingController();
  final _notes = TextEditingController();
  String _status = 'Normal';
  bool _loading = false;
  double? _lastHm;

  @override
  void dispose() {
    for (final c in [
      _attendant, _hourMeter, _powerMeter, _waterMeter,
      _fuelAdded, _faultCode, _cause, _resolution, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<OpTypeDef> _opsFor(AssetSystem? sys) {
    if (widget.fuelingOnly) {
      return OperationCatalog.types.where((o) => o.key == 'gen_fueling').toList();
    }
    if (widget.breakdownOnly) {
      return OperationCatalog.types.where((o) => o.key == 'breakdown_report').toList();
    }
    return OperationCatalog.forSystemType(sys?.type);
  }

  Future<void> _onSystemChanged(String? id, List<AssetSystem> systems) async {
    setState(() {
      _systemId = id;
      _opKey = null;
      _lastHm = null;
    });
    if (id == null) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    final hm = await ref.read(operationsRepositoryProvider).latestHourMeter(org.id, id);
    if (mounted) setState(() => _lastHm = hm);
    final sys = systems.where((s) => s.id == id).firstOrNull;
    final ops = _opsFor(sys);
    if (ops.isNotEmpty) {
      setState(() {
        _opKey = ops.first.key;
        _opMode = ops.first.modes.first;
      });
    }
  }

  Future<void> _save() async {
    if (_systemId == null || _opKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select system and operation type')),
      );
      return;
    }
    final org = ref.read(activeOrganizationProvider);
    final user = ref.read(currentUserProvider);
    if (org == null) return;
    final systems = ref.read(systemsListProvider).valueOrNull ?? [];
    final sys = systems.where((s) => s.id == _systemId).firstOrNull;

    setState(() => _loading = true);
    try {
      await ref.read(operationsRepositoryProvider).createRecord(
            organizationId: org.id,
            systemId: _systemId!,
            opKey: _opKey!,
            opMode: _opMode,
            attendant: _attendant.text,
            status: _status,
            hourMeter: double.tryParse(_hourMeter.text),
            powerMeter: double.tryParse(_powerMeter.text),
            waterMeter: double.tryParse(_waterMeter.text),
            fuelAdded: double.tryParse(_fuelAdded.text),
            fuelCapacity: sys?.fuelTankCapacity,
            faultCode: _faultCode.text.trim().isEmpty ? null : _faultCode.text.trim(),
            cause: _cause.text.trim().isEmpty ? null : _cause.text.trim(),
            resolution: _resolution.text.trim().isEmpty ? null : _resolution.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            systemType: sys?.type,
            systemSerial: sys?.serialNumber,
            clientName: sys?.clientName,
            clientSite: sys?.clientSite,
            performedBy: user?.email,
          );
      ref.invalidate(operationRecordsProvider);
      ref.invalidate(opsTodayCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operation recorded')),
      );
      context.go('/operations/records');
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
    final systems = ref.watch(systemsListProvider).valueOrNull ?? [];
    final sys = systems.where((s) => s.id == _systemId).firstOrNull;
    final ops = _opsFor(sys);
    final selectedOp = ops.where((o) => o.key == _opKey).firstOrNull;

    String title = 'Record operation';
    if (widget.fuelingOnly) title = 'Log fueling';
    if (widget.breakdownOnly) title = 'Report breakdown';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          DropdownButtonFormField<String>(
            value: _systemId != null && systems.any((s) => s.id == _systemId) ? _systemId : null,
            decoration: const InputDecoration(labelText: 'System *'),
            items: systems
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.type ?? s.name} · ${s.serialNumber ?? s.clientName ?? ''}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => _onSystemChanged(v, systems),
          ),
          if (_lastHm != null) ...[
            const SizedBox(height: 8),
            Text('Last hour meter: ${_lastHm!.toStringAsFixed(1)} hrs',
                style: const TextStyle(color: GlossColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          if (ops.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _opKey != null && ops.any((o) => o.key == _opKey) ? _opKey : null,
              decoration: const InputDecoration(labelText: 'Operation type *'),
              items: ops
                  .map((o) => DropdownMenuItem(value: o.key, child: Text(o.name)))
                  .toList(),
              onChanged: (v) {
                final op = ops.where((o) => o.key == v).firstOrNull;
                setState(() {
                  _opKey = v;
                  _opMode = op?.modes.first ?? 'single';
                });
              },
            ),
          if (selectedOp != null && selectedOp.modes.length > 1) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: selectedOp.modes
                  .map((m) => ButtonSegment(value: m, label: Text(m[0].toUpperCase() + m.substring(1))))
                  .toList(),
              selected: {_opMode},
              onSelectionChanged: (s) => setState(() => _opMode = s.first),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _attendant,
            decoration: const InputDecoration(labelText: 'Attendant'),
          ),
          const SizedBox(height: 12),
          if (_opKey != 'gen_fueling' && _opKey != 'breakdown_report')
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                DropdownMenuItem(value: 'Faulty', child: Text('Faulty')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'Normal'),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _hourMeter,
            decoration: InputDecoration(
              labelText: _opKey == 'gen_fueling' ? 'Current hour meter (Hrs)' : 'Hour meter (Hrs)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_opKey != 'breakdown_report' && _opKey != 'gen_fueling') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _powerMeter,
              decoration: const InputDecoration(labelText: 'Power meter (kWh)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _waterMeter,
              decoration: const InputDecoration(labelText: 'Water / flow meter (m³)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          if (_opKey == 'gen_fueling') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _fuelAdded,
              decoration: const InputDecoration(labelText: 'Fuel added (L)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (sys?.fuelTankCapacity != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Tank capacity: ${sys!.fuelTankCapacity} L',
                    style: const TextStyle(color: GlossColors.muted, fontSize: 12)),
              ),
          ],
          if (_opKey == 'breakdown_report') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _faultCode,
              decoration: const InputDecoration(labelText: 'Fault code'),
            ),
            const SizedBox(height: 12),
            if (_opMode == 'report')
              TextFormField(
                controller: _cause,
                decoration: const InputDecoration(labelText: 'What you observed'),
                maxLines: 3,
              ),
            if (_opMode == 'resolved')
              TextFormField(
                controller: _resolution,
                decoration: const InputDecoration(labelText: 'What fixed it'),
                maxLines: 3,
              ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
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
                : const Text('Save record'),
          ),
        ),
      ),
    );
  }
}

class OperationRecordsScreen extends ConsumerWidget {
  const OperationRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(operationRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operation records'),
        actions: [
          IconButton(
            onPressed: () => context.push('/operations/record'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(operationRecordsProvider);
          ref.invalidate(opsTodayCountProvider);
          await ref.read(operationRecordsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 48),
                const Center(child: Text('No operation records yet')),
                Center(
                  child: FilledButton(
                    onPressed: () => context.push('/operations/record'),
                    child: const Text('Record first operation'),
                  ),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = items[i];
                return Card(
                  child: ListTile(
                    title: Text('${r.opLabel} · ${r.opMode}'),
                    subtitle: Text(
                      [
                        r.subtitle,
                        if (r.recordedAt != null)
                          r.recordedAt!.toLocal().toString().split('.').first,
                      ].join('\n'),
                      style: const TextStyle(color: GlossColors.muted, fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: r.status != null
                        ? Chip(
                            label: Text(r.status!, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/operations/record'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
