import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../clients/client_models.dart';
import '../clients/client_providers.dart';
import '../org/org_providers.dart';
import 'work_models.dart';
import 'work_providers.dart';

class WorkRequestFormScreen extends ConsumerStatefulWidget {
  const WorkRequestFormScreen({super.key});

  @override
  ConsumerState<WorkRequestFormScreen> createState() =>
      _WorkRequestFormScreenState();
}

class _WorkRequestFormScreenState extends ConsumerState<WorkRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _fault = TextEditingController();
  final _notes = TextEditingController();

  Client? _client;
  AssetSystem? _system;
  String _jobType = 'corrective';
  String _priority = 'medium';
  bool _needsProcurement = false;
  bool _loading = false;

  @override
  void dispose() {
    _description.dispose();
    _fault.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    if (_system == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a system')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider);
      final wr = await ref.read(workRepositoryProvider).createRequest(
            organizationId: org.id,
            description: _description.text,
            clientId: _client?.id ?? _system!.clientId,
            systemId: _system!.id,
            clientName: _client?.name ?? _system!.clientName,
            clientSite: _client?.siteName ?? _system!.clientSite,
            systemType: _system!.type,
            systemModel: _system!.model,
            systemSerial: _system!.serialNumber,
            jobType: _jobType,
            priority: _priority,
            requestedBy: user?.email,
            faultDescription: _fault.text,
            notes: _notes.text,
            needsProcurement: _needsProcurement,
          );
      ref.invalidate(workRequestsListProvider);
      ref.invalidate(pendingWorkRequestsCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${wr.wrNumber} created')),
      );
      context.go('/work/requests/${wr.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);
    final systemsAsync = ref.watch(systemsListProvider);
    final systems = systemsAsync.valueOrNull ?? [];
    final filteredSystems = _client == null
        ? systems
        : systems.where((s) => s.clientId == _client!.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('New work request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            const Text('ASSET',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: GlossColors.muted)),
            const SizedBox(height: 8),
            clientsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (clients) => DropdownButtonFormField<Client>(
                value: _client != null && clients.any((c) => c.id == _client!.id)
                    ? clients.firstWhere((c) => c.id == _client!.id)
                    : null,
                decoration: const InputDecoration(labelText: 'Client'),
                items: clients
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displaySite, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (c) => setState(() {
                  _client = c;
                  _system = null;
                }),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AssetSystem>(
              value: _system != null && filteredSystems.any((s) => s.id == _system!.id)
                  ? filteredSystems.firstWhere((s) => s.id == _system!.id)
                  : null,
              decoration: const InputDecoration(labelText: 'System *'),
              items: filteredSystems
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          '${s.name}${s.serialNumber != null ? ' · ${s.serialNumber}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (s) => setState(() {
                _system = s;
                if (s?.clientId != null && _client == null) {
                  final clients = clientsAsync.valueOrNull ?? [];
                  _client = clients.cast<Client?>().firstWhere(
                        (c) => c?.id == s!.clientId,
                        orElse: () => null,
                      );
                }
              }),
              validator: (v) => v == null ? 'Required' : null,
            ),
            if (systems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () => context.push('/systems/new'),
                  child: const Text('Register a system first'),
                ),
              ),
            const SizedBox(height: 20),
            const Text('JOB',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: GlossColors.muted)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _jobType,
              decoration: const InputDecoration(labelText: 'Job type'),
              items: WorkJobTypes.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _jobType = v ?? 'corrective'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: WorkPriorities.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'What needs to be done?',
              ),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fault,
              decoration: const InputDecoration(labelText: 'Fault / symptoms'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Needs procurement'),
              subtitle: const Text('Parts may be required from suppliers'),
              value: _needsProcurement,
              onChanged: (v) => setState(() => _needsProcurement = v),
            ),
          ],
        ),
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
                : const Text('Submit request'),
          ),
        ),
      ),
    );
  }
}
