import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'client_providers.dart';

/// Entry point for the Registration module (production Systems menu parity).
class RegistrationHubScreen extends ConsumerWidget {
  const RegistrationHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsListProvider).valueOrNull?.length;
    final systems = ref.watch(systemsListProvider).valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Registration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Master data',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: GlossColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.person_add_alt_1_outlined,
            title: 'Register client',
            subtitle: 'New customer / site',
            route: '/clients/new',
          ),
          _tile(
            context,
            icon: Icons.people_outlined,
            title: 'Client profiles',
            subtitle: clients == null ? 'Browse clients' : '$clients client(s)',
            route: '/clients',
          ),
          _tile(
            context,
            icon: Icons.memory_outlined,
            title: 'Register system',
            subtitle: 'Asset linked to a client',
            route: '/systems/new',
          ),
          _tile(
            context,
            icon: Icons.list_alt_outlined,
            title: 'View systems',
            subtitle:
                systems == null ? 'Browse assets' : '$systems system(s)',
            route: '/systems',
          ),
          const SizedBox(height: 24),
          const Text(
            'Workflow',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: GlossColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '1. Register client (site + contact + SLA)\n'
                '2. Save & attach → register system on that client\n'
                '3. Or open client → Systems tab → Attach system',
                style: TextStyle(height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: GlossColors.accent),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
