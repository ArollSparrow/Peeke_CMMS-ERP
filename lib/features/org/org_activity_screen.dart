import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import 'org_providers.dart';
import 'org_team_models.dart';

/// Elevated-only audit trail for team actions.
class OrgActivityScreen extends ConsumerWidget {
  const OrgActivityScreen({super.key});

  static String labelForAction(String action) {
    switch (action) {
      case 'invite_sent':
        return 'Invite sent';
      case 'invite_revoked':
        return 'Invite cancelled';
      case 'member_updated':
        return 'Member updated';
      case 'member_removed':
        return 'Member removed';
      case 'ownership_transferred':
        return 'Ownership transferred';
      case 'bulk_invite':
        return 'Bulk invite';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  static IconData iconForAction(String action) {
    switch (action) {
      case 'invite_sent':
      case 'bulk_invite':
        return Icons.mail_outline;
      case 'invite_revoked':
        return Icons.cancel_outlined;
      case 'member_updated':
        return Icons.edit_outlined;
      case 'member_removed':
        return Icons.person_remove_outlined;
      case 'ownership_transferred':
        return Icons.swap_horiz;
      default:
        return Icons.history;
    }
  }

  String _when(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().toUtc().difference(t.toUtc());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 48) return '${d.inHours}h ago';
    if (d.inDays < 14) return '${d.inDays}d ago';
    final local = t.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(orgCapabilitiesProvider);
    final rows = ref.watch(orgActivityProvider);

    if (!caps.isElevated) {
      return Scaffold(
        backgroundColor: GlossColors.sky,
        appBar: AppBar(title: const Text('Activity')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Activity log is available to elevated roles only.',
            style: GlossSurfaces.logoAccent,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GlossColors.sky,
      appBar: AppBar(
        title: const Text('Team activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(orgActivityProvider),
          ),
        ],
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(friendlyError(e)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No team activity recorded yet. Invites, member changes, '
                'and ownership transfers will appear here.',
                style: GlossSurfaces.logoAccent,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final a = list[i];
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: GlossSurfaces.plate,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      iconForAction(a.action),
                      size: 20,
                      color: GlossColors.tealDeep,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelForAction(a.action),
                            style: GlossSurfaces.tileMeta,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.summary,
                            style: GlossSurfaces.tileName,
                          ),
                          if (a.actorLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'By ${a.actorLabel}',
                              style: GlossSurfaces.logoAccent
                                  .copyWith(fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      _when(a.createdAt),
                      style: GlossSurfaces.logoAccent.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
