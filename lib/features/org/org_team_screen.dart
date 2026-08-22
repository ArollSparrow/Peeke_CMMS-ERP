import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import 'org_providers.dart';
import 'org_team_invite_panel.dart';
import 'org_team_models.dart';

export 'org_team_models.dart';

/// Team hub: multi-invite panel + AppBar logo. Directory list restored next.
class OrgTeamScreen extends ConsumerWidget {
  const OrgTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(orgCapabilitiesProvider);
    final canInvite = caps.isElevated;
    return Scaffold(
      backgroundColor: GlossColors.sky,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/branding/peeke_icon.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 10),
            const Text('Team'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Roles',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => context.push('/org/roles'),
          ),
          if (canInvite) ...[
            IconButton(
              tooltip: 'Activity',
              icon: const Icon(Icons.history),
              onPressed: () => context.push('/org/team/activity'),
            ),
            IconButton(
              tooltip: 'Departments',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => context.push('/org/departments'),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (canInvite)
            const OrgTeamInvitePanel()
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Directory is open to all members. Only elevated roles can invite or edit.',
                style: GlossSurfaces.logoAccent,
              ),
            ),
          Text(
            'Member list loading next — invites work above.',
            style: GlossSurfaces.logoAccent,
          ),
        ],
      ),
    );
  }
}
