import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../clients/client_models.dart';
import '../clients/client_providers.dart';
import '../org/org_providers.dart';
import 'work_models.dart';
import 'work_providers.dart';

class WorkOrderFormScreen extends ConsumerStatefulWidget {
  const WorkOrderFormScreen({super.key});

  @override
  ConsumerState<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends ConsumerState<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _fault = TextEditingController();
  final _tech = TextEditingController();

  Client? _client;
  AssetSystem? _system;
  String _jobType = 'corrective';
  String _priority = 'medium';
  bool _loading = false;

  @override
  void dispose() {
    _description.dispose();
    _fault.dispose();
    _tech.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null || _system == null) return;

    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider);
      final wo = await ref.read(workRepositoryProvider).createOrder(
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
            assignedTechnician: _tech.text.trim().isEmpty ? null : _tech.text,
          );
      ref.invalidate(workOrdersListProvider);
      ref.invalidate(openWorkOrdersCountProvider);
      if (!mounted) return;
      context.go('/work/orders/${wo.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsListProvider).valueOrNull ?? [];
    final systems = ref.watch(systemsListProvider).valueOrNull ?? [];
    final filtered = _client == null
        ? systems
        : systems.where((s) => s.clientId == _client!.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('New work order')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            DropdownButtonFormField<Client>(
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
            const SizedBox(height: 12),
            DropdownButtonFormField<AssetSystem>(
              value: _system != null && filtered.any((s) => s.id == _system!.id)
                  ? filtered.firstWhere((s) => s.id == _system!.id)
                  : null,
              decoration: const InputDecoration(labelText: 'System *'),
              items: filtered
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (s) => setState(() => _system = s),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
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
              decoration: const InputDecoration(labelText: 'Description *'),
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
              controller: _tech,
              decoration: const InputDecoration(labelText: 'Assigned technician'),
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
                : const Text('Create work order'),
          ),
        ),
      ),
    );
  }
}
