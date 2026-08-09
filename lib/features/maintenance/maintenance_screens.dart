import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../clients/client_providers.dart';
import '../org/org_providers.dart';
import 'maintenance_models.dart';
import 'maintenance_providers.dart';

// ── Hub ──────────────────────────────────────────────────────

class MaintenanceHubScreen extends ConsumerWidget {
  const MaintenanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(duePmCountProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _t(context, Icons.event_repeat_outlined, 'PM Plans',
              due == null ? 'Schedules & service status' : '$due due/overdue', '/maintenance/plans'),
          _t(context, Icons.build_circle_outlined, 'Log maintenance job',
              'Scheduled or corrective service', '/maintenance/jobs/new'),
          _t(context, Icons.history, 'Service history',
              'Past jobs & reliability', '/maintenance/history'),
          _t(context, Icons.timer_outlined, 'Downtime',
              'Logged outages linked to jobs', '/maintenance/downtime'),
          _t(context, Icons.people_outline, 'Technicians',
              'Roster for job assignment', '/maintenance/technicians'),
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

// ── Technicians ──────────────────────────────────────────────

class TechniciansListScreen extends ConsumerWidget {
  const TechniciansListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(techniciansListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technicians'),
        actions: [
          IconButton(
            onPressed: () => _showForm(context, ref),
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(techniciansListProvider);
          await ref.read(techniciansListProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 48),
                const Center(child: Text('No technicians yet')),
                Center(
                  child: FilledButton(
                    onPressed: () => _showForm(context, ref),
                    child: const Text('Add technician'),
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
                    leading: CircleAvatar(
                      backgroundColor: GlossColors.accent.withValues(alpha: 0.15),
                      child: Icon(Icons.person, color: GlossColors.accent, size: 20),
                    ),
                    title: Text(t.name),
                    subtitle: Text(t.subtitle, style: const TextStyle(color: GlossColors.muted)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showForm(context, ref, existing: t),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref, {Technician? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final spec = TextEditingController(text: existing?.specialisation ?? '');
    final contact = TextEditingController(text: existing?.contact ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add technician' : 'Edit technician'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *'), autofocus: true),
            TextField(controller: spec, decoration: const InputDecoration(labelText: 'Specialisation')),
            TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(existing == null ? 'Add' : 'Update')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (existing != null) {
        await repo.updateTechnician(existing.id, {
          'name': name.text.trim(),
          'specialisation': spec.text.trim().isEmpty ? null : spec.text.trim(),
          'contact': contact.text.trim().isEmpty ? null : contact.text.trim(),
        });
      } else {
        await repo.createTechnician(
          organizationId: org.id,
          name: name.text,
          specialisation: spec.text,
          contact: contact.text,
        );
      }
      ref.invalidate(techniciansListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

// ── PM Plans list ────────────────────────────────────────────

class PmPlansListScreen extends ConsumerStatefulWidget {
  const PmPlansListScreen({super.key});

  @override
  ConsumerState<PmPlansListScreen> createState() => _PmPlansListScreenState();
}

class _PmPlansListScreenState extends ConsumerState<PmPlansListScreen> {
  String _filter = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pmPlansListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PM Plans'),
        actions: [
          IconButton(
            onPressed: () => context.push('/maintenance/plans/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search title, system, client…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['all', 'overdue', 'due', 'upcoming', 'inactive']
                  .map((s) {
                final sel = _filter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: sel,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pmPlansListProvider);
                ref.invalidate(duePmCountProvider);
                await ref.read(pmPlansListProvider.future);
              },
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
                data: (plans) {
                  var list = plans;
                  if (_filter != 'all') {
                    list = list.where((p) => p.planStatus == _filter).toList();
                  }
                  if (_q.isNotEmpty) {
                    list = list.where((p) {
                      final hay =
                          '${p.title} ${p.systemSerial ?? ''} ${p.clientName ?? ''} ${p.systemType ?? ''}'
                              .toLowerCase();
                      return hay.contains(_q);
                    }).toList();
                  }
                  if (list.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 48),
                      Center(child: Text(plans.isEmpty ? 'No PM plans yet' : 'No matches')),
                      Center(
                        child: FilledButton(
                          onPressed: () => context.push('/maintenance/plans/new'),
                          child: const Text('Create PM plan'),
                        ),
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _PlanCard(plan: list[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/maintenance/plans/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final PmPlan plan;

  Color _statusColor(String s) {
    switch (s) {
      case 'overdue':
        return GlossColors.danger;
      case 'due':
        return const Color(0xFFF59E0B);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'upcoming':
        return const Color(0xFF16A34A);
      default:
        return GlossColors.muted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = plan.planStatus;
    final col = _statusColor(status);
    return Card(
      child: InkWell(
        onTap: () => context.push('/maintenance/plans/${plan.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  if (plan.isMeter)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: GlossColors.danger.withValues(alpha: 0.12),
                      ),
                      child: const Text('METER',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GlossColors.danger)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: col.withValues(alpha: 0.12),
                      border: Border.all(color: col.withValues(alpha: 0.4)),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(plan.systemLine, style: const TextStyle(color: GlossColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _badge(plan.intervalLabel),
                  const SizedBox(width: 6),
                  _badge(plan.priority),
                  if (plan.autoGenerateWo) ...[
                    const SizedBox(width: 6),
                    _badge(plan.generates == 'work_request' ? 'Auto WR' : 'Auto WO'),
                  ],
                  const Spacer(),
                  if (plan.openWoCount > 0)
                    Text('${plan.openWoCount} open WO',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
                  if (plan.openWrNumber != null)
                    Text('WR ${plan.openWrNumber}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: GlossColors.pageBg,
          border: Border.all(color: GlossColors.border),
        ),
        child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ── New / Edit PM Plan ───────────────────────────────────────

class PmPlanFormScreen extends ConsumerStatefulWidget {
  const PmPlanFormScreen({super.key, this.planId, this.preselectedSystemId});
  final String? planId;
  final String? preselectedSystemId;
  bool get isEdit => planId != null;

  @override
  ConsumerState<PmPlanFormScreen> createState() => _PmPlanFormScreenState();
}

class _PmPlanFormScreenState extends ConsumerState<PmPlanFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _systemId;
  String _trigger = 'calendar';
  int _intervalValue = 3;
  String _intervalUnit = 'months';
  int? _meterHours = 250;
  String _priority = 'medium';
  String _generates = 'work_order';
  bool _autoWo = true;
  bool _loading = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _hydrate(PmPlan p) {
    if (_hydrated) return;
    _hydrated = true;
    _title.text = p.title;
    _desc.text = p.description ?? '';
    _systemId = p.systemId;
    _trigger = p.triggerType;
    _intervalValue = p.intervalValue;
    _intervalUnit = p.intervalUnit;
    _meterHours = p.meterIntervalHours ?? 250;
    _priority = p.priority;
    _generates = p.generates;
    _autoWo = p.autoGenerateWo;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title required')));
      return;
    }
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    if (!widget.isEdit && _systemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a system')));
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (widget.isEdit) {
        await repo.updatePmPlan(widget.planId!, {
          'title': _title.text.trim(),
          'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          'interval_value': _trigger == 'meter' ? (_meterHours ?? 250) : _intervalValue,
          'interval_unit': _trigger == 'meter' ? 'hours' : _intervalUnit,
          'meter_interval_hours': _trigger == 'meter' ? _meterHours : null,
          'priority': _priority,
          'auto_generate_wo': _autoWo,
          'generates': _generates,
        });
        ref.invalidate(pmPlanByIdProvider(widget.planId!));
      } else {
        final po = await repo.createPmPlan(
          organizationId: org.id,
          systemId: _systemId!,
          title: _title.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          triggerType: _trigger,
          intervalValue: _trigger == 'meter' ? (_meterHours ?? 250) : _intervalValue,
          intervalUnit: _trigger == 'meter' ? 'hours' : _intervalUnit,
          priority: _priority,
          autoGenerateWo: _autoWo,
          generates: _generates,
          meterIntervalHours: _trigger == 'meter' ? _meterHours : null,
        );
        ref.invalidate(pmPlansListProvider);
        ref.invalidate(duePmCountProvider);
        if (!mounted) return;
        context.go('/maintenance/plans/${po.id}');
        return;
      }
      ref.invalidate(pmPlansListProvider);
      ref.invalidate(duePmCountProvider);
      if (!mounted) return;
      context.pop();
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
    if (widget.isEdit) {
      ref.watch(pmPlanByIdProvider(widget.planId!)).whenData((p) {
        if (p != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hydrate(p));
          });
        }
      });
    } else if (widget.preselectedSystemId != null && _systemId == null) {
      _systemId = widget.preselectedSystemId;
    }

    final systems = ref.watch(systemsListProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit PM plan' : 'New PM plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (!widget.isEdit)
            DropdownButtonFormField<String>(
              value: _systemId != null && systems.any((s) => s.id == _systemId) ? _systemId : null,
              decoration: const InputDecoration(labelText: 'System *'),
              items: systems
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.type ?? s.name} · ${s.serialNumber ?? s.id.substring(0, 8)}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _systemId = v),
            ),
          if (!widget.isEdit) const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Plan title *'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'SOP / work description'),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          const Text('Trigger', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'calendar', label: Text('Calendar'), icon: Icon(Icons.calendar_month, size: 16)),
              ButtonSegment(value: 'meter', label: Text('Hour meter'), icon: Icon(Icons.speed, size: 16)),
            ],
            selected: {_trigger},
            onSelectionChanged: widget.isEdit
                ? null
                : (s) => setState(() => _trigger = s.first),
          ),
          const SizedBox(height: 16),
          if (_trigger == 'calendar') ...[
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    if (_intervalValue > 1) _intervalValue--;
                  }),
                  icon: const Icon(Icons.remove),
                ),
                Text('$_intervalValue', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: () => setState(() => _intervalValue++),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: ['days', 'weeks', 'months']
                        .map((u) => ChoiceChip(
                              label: Text(u),
                              selected: _intervalUnit == u,
                              onSelected: (_) => setState(() => _intervalUnit = u),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              children: [250, 500, 1000]
                  .map((h) => ChoiceChip(
                        label: Text('$h hrs'),
                        selected: _meterHours == h,
                        onSelected: (_) => setState(() => _meterHours = h),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['low', 'medium', 'high', 'critical']
                .map((p) => ChoiceChip(
                      label: Text(p),
                      selected: _priority == p,
                      onSelected: (_) => setState(() => _priority = p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto-generate on schedule'),
            subtitle: const Text('Create WO or WR when plan triggers'),
            value: _autoWo,
            onChanged: (v) => setState(() => _autoWo = v),
          ),
          if (_autoWo) ...[
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'work_order', label: Text('Work Order')),
                ButtonSegment(value: 'work_request', label: Text('Work Request')),
              ],
              selected: {_generates},
              onSelectionChanged: (s) => setState(() => _generates = s.first),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.isEdit ? 'Save changes' : 'Create PM plan'),
          ),
        ),
      ),
    );
  }
}

// ── Log job ──────────────────────────────────────────────────

class LogMaintenanceJobScreen extends ConsumerStatefulWidget {
  const LogMaintenanceJobScreen({super.key});

  @override
  ConsumerState<LogMaintenanceJobScreen> createState() => _LogMaintenanceJobScreenState();
}

class _LogMaintenanceJobScreenState extends ConsumerState<LogMaintenanceJobScreen> {
  final _title = TextEditingController();
  final _findings = TextEditingController();
  final _workDone = TextEditingController();
  final _hourMeter = TextEditingController();
  String? _systemId;
  String? _technicianId;
  String _jobType = 'corrective';
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _findings.dispose();
    _workDone.dispose();
    _hourMeter.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _systemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and system are required')),
      );
      return;
    }
    final org = ref.read(activeOrganizationProvider);
    final user = ref.read(currentUserProvider);
    if (org == null) return;
    setState(() => _loading = true);
    try {
      final systems = ref.read(systemsListProvider).valueOrNull ?? [];
      final sys = systems.where((s) => s.id == _systemId).firstOrNull;
      await ref.read(maintenanceRepositoryProvider).createRecord(
            organizationId: org.id,
            systemId: _systemId!,
            title: _title.text.trim(),
            technicianId: _technicianId,
            jobType: _jobType,
            findings: _findings.text.trim().isEmpty ? null : _findings.text.trim(),
            workDone: _workDone.text.trim().isEmpty ? null : _workDone.text.trim(),
            hourMeter: double.tryParse(_hourMeter.text),
            performedBy: user?.email,
            systemType: sys?.type,
            systemSerial: sys?.serialNumber,
            clientName: sys?.clientName,
          );
      ref.invalidate(maintenanceRecordsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance job logged')),
      );
      context.go('/maintenance/history');
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
    final techs = ref.watch(techniciansListProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Log maintenance job')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          DropdownButtonFormField<String>(
            value: _systemId != null && systems.any((s) => s.id == _systemId) ? _systemId : null,
            decoration: const InputDecoration(labelText: 'System *'),
            items: systems
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.type ?? s.name} · ${s.serialNumber ?? ''}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _systemId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Job title *'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _jobType,
            decoration: const InputDecoration(labelText: 'Job type'),
            items: const [
              DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
              DropdownMenuItem(value: 'corrective', child: Text('Corrective')),
              DropdownMenuItem(value: 'inspection', child: Text('Inspection')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _jobType = v ?? 'corrective'),
          ),
          const SizedBox(height: 12),
          if (techs.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _technicianId != null && techs.any((t) => t.id == _technicianId)
                  ? _technicianId
                  : null,
              decoration: const InputDecoration(labelText: 'Technician'),
              items: techs
                  .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _technicianId = v),
            ),
          if (techs.isNotEmpty) const SizedBox(height: 12),
          TextFormField(
            controller: _hourMeter,
            decoration: const InputDecoration(labelText: 'Hour meter (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _findings,
            decoration: const InputDecoration(labelText: 'Findings'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _workDone,
            decoration: const InputDecoration(labelText: 'Work done'),
            maxLines: 3,
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
                : const Text('Log job'),
          ),
        ),
      ),
    );
  }
}
