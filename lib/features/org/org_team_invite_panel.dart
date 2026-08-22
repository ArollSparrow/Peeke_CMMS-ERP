import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import '../auth/login_screen.dart' show authRedirectTo;
import 'org_providers.dart';
import 'org_roles.dart';
import 'org_team_models.dart';

/// Client-side email check aligned with invite-org-member EMAIL_RE.
final inviteEmailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class _InviteDraft {
  _InviteDraft({this.role = OrgRoles.technician})
      : email = TextEditingController();

  final TextEditingController email;
  String role;

  void dispose() => email.dispose();
}

/// Multi-email, per-row role invite form for Team screen.
class OrgTeamInvitePanel extends ConsumerStatefulWidget {
  const OrgTeamInvitePanel({super.key});

  @override
  ConsumerState<OrgTeamInvitePanel> createState() => _OrgTeamInvitePanelState();
}

class _OrgTeamInvitePanelState extends ConsumerState<OrgTeamInvitePanel> {
  final List<_InviteDraft> _drafts = [_InviteDraft()];
  bool _busy = false;
  String? _message;
  String? _error;
  String? _actionLink;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDraft() => setState(() => _drafts.add(_InviteDraft()));

  void _removeDraft(int index) {
    if (_drafts.length <= 1) {
      _drafts[0].email.clear();
      setState(() => _drafts[0].role = OrgRoles.technician);
      return;
    }
    setState(() => _drafts.removeAt(index).dispose());
  }

  Future<void> _sendAll() async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;

    final entries = <MapEntry<String, String>>[];
    for (final d in _drafts) {
      final email = d.email.text.trim().toLowerCase();
      if (email.isEmpty) continue;
      if (!inviteEmailRe.hasMatch(email)) {
        setState(() => _error = 'Invalid email: $email');
        return;
      }
      entries.add(MapEntry(email, d.role));
    }
    if (entries.isEmpty) {
      setState(() => _error = 'Add at least one work email');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _actionLink = null;
    });

    var okCount = 0;
    var failCount = 0;
    String? lastLink;
    final roleCounts = <String, int>{};

    try {
      final client = ref.read(supabaseClientProvider);
      for (final e in entries) {
        try {
          final res = await client.functions.invoke(
            'invite-org-member',
            body: {
              'organization_id': org.id,
              'email': e.key,
              'role': e.value,
              'redirect_to': authRedirectTo('/accept-invite'),
            },
          );
          final data = res.data;
          if (data is Map &&
              data['error'] != null &&
              data['status'] == null) {
            failCount++;
          } else {
            okCount++;
            roleCounts[e.value] = (roleCounts[e.value] ?? 0) + 1;
            if (data is Map) {
              final link = data['action_link']?.toString();
              if (link != null && link.isNotEmpty) lastLink = link;
            }
          }
        } catch (_) {
          failCount++;
        }
      }
      ref.invalidate(orgInvitesProvider);
      ref.invalidate(orgMembersProvider);

      if (okCount > 0) {
        for (final d in _drafts) {
          d.email.clear();
        }
        setState(() {
          while (_drafts.length > 1) {
            _drafts.removeLast().dispose();
          }
          _drafts[0].role = OrgRoles.technician;
        });
        final roleSummary = roleCounts.entries
            .map((e) => '${e.value}× ${OrgRoles.label(e.key)}')
            .join(', ');
        await logOrgActivity(
          ref,
          action: entries.length > 1 ? 'bulk_invite' : 'invite_sent',
          summary: entries.length > 1
              ? 'Invited $okCount member(s) ($roleSummary)'
              : 'Invited ${entries.first.key} as ${OrgRoles.label(entries.first.value)}',
          metadata: {
            'ok': okCount,
            'failed': failCount,
            'roles': roleCounts,
          },
        );
      }
      setState(() {
        _message =
            'Invites: $okCount sent${failCount > 0 ? ', $failCount failed' : ''}';
        _actionLink = lastLink;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    final link = _actionLink;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invite link copied — share via WhatsApp/SMS')),
      );
    }
  }

  Widget _field({required Widget child}) =>
      GlossSurfaces.fieldShell(child: child);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Invite members',
          style: GlossSurfaces.logoMark.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add one or more work emails. Choose a role for each person.',
          style: GlossSurfaces.logoAccent.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _drafts.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _field(
                  child: TextField(
                    controller: _drafts[i].email,
                    keyboardType: TextInputType.emailAddress,
                    style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
                    cursorColor: GlossColors.navy,
                    decoration:
                        GlossSurfaces.compactField('Work email').copyWith(
                      hintText: 'name@company.com',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _field(
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _drafts[i].role,
                    isDense: true,
                    isExpanded: true,
                    iconSize: 18,
                    style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
                    decoration: GlossSurfaces.compactField('Role'),
                    items: [
                      for (final r in OrgRoles.inviteChoices)
                        DropdownMenuItem(
                          value: r,
                          child: Text(
                            OrgRoles.label(r),
                            style:
                                GlossSurfaces.logoMark.copyWith(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(
                      () => _drafts[i].role = v ?? OrgRoles.technician,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _drafts.length <= 1 ? 'Clear' : 'Remove',
                onPressed: _busy ? null : () => _removeDraft(i),
                icon: Icon(
                  _drafts.length <= 1
                      ? Icons.clear
                      : Icons.remove_circle_outline,
                  size: 20,
                  color: GlossColors.navy.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _addDraft,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text('Add another', style: GlossSurfaces.logoMark),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: GlossSurfaces.glossCta(
            label: _drafts.length > 1 ? 'SEND INVITES' : 'SEND INVITE',
            onTap: () => _sendAll(),
            busy: _busy,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: GlossSurfaces.fieldGap),
          Text(_error!,
              style: GlossSurfaces.logoMark.copyWith(color: GlossColors.danger)),
        ],
        if (_message != null) ...[
          const SizedBox(height: GlossSurfaces.fieldGap),
          Text(_message!, style: GlossSurfaces.logoAccent),
        ],
        if (_actionLink != null) ...[
          const SizedBox(height: 12),
          Text(
            'Share invite link (WhatsApp / SMS) if email is delayed:',
            style: GlossSurfaces.logoMark,
          ),
          const SizedBox(height: 6),
          SelectableText(_actionLink!,
              style: GlossSurfaces.logoAccent.copyWith(fontSize: 12)),
          TextButton.icon(
            onPressed: _copyLink,
            icon: const Icon(Icons.copy, size: 18),
            label: Text('Copy invite link', style: GlossSurfaces.logoMark),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
