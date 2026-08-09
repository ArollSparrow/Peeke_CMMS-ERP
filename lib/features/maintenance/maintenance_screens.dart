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
