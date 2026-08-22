import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import 'org_providers.dart';
import 'org_roles.dart';
import 'org_team_models.dart';

/// Read-only role hierarchy + capability notes (all members).
class OrgRolesScreen extends ConsumerWidget {
  const OrgRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(orgMembersProvider).valueOrNull ?? [];
    final counts = <String, int>{};
    for (final m in members) {
      counts[m.role] = (counts[m.role] ?? 0) + 1;
    }
    final myRole = ref.watch(activeMembershipRoleProvider).valueOrNull;

    return Scaffold(
      backgroundColor: GlossColors.sky,
      appBar: AppBar(title: const Text('Roles')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Organisation roles are fixed across tenants. Elevated roles can '
            'invite, edit members, and manage departments. HoD is both a role '
            'and a department assignment (long-press a dept chip on a member).',
            style: GlossSurfaces.logoAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'HIERARCHY',
            style: GlossSurfaces.logoAccent.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: GlossSurfaces.fieldGap),
          for (final code in OrgRoles.hierarchy)
            _RoleTile(
              code: code,
              count: counts[code] ?? 0,
              isYou: myRole == code,
              elevated: OrgRoles.isElevatedRole(code),
            ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.code,
    required this.count,
    required this.isYou,
    required this.elevated,
  });

  final String code;
  final int count;
  final bool isYou;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[];
    if (elevated) meta.add('Elevated');
    if (count > 0) meta.add(count == 1 ? '1 member' : '$count members');
    if (isYou) meta.add('You');
    final metaLine = meta.isEmpty ? '—' : meta.join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: GlossSurfaces.plate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metaLine, style: GlossSurfaces.tileMeta),
          Text(OrgRoles.label(code), style: GlossSurfaces.tileName),
          const SizedBox(height: 4),
          Text(
            OrgRoles.capability(code),
            style: GlossSurfaces.logoAccent.copyWith(fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }
}
