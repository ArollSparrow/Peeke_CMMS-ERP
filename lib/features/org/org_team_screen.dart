import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import '../auth/login_screen.dart' show authRedirectTo;
import 'member_edit_dialog.dart';
import 'org_providers.dart';
import 'org_roles.dart';
import 'org_team_invite_panel.dart';
import 'org_team_models.dart';
import 'org_team_tiles.dart';

export 'org_team_models.dart';

enum _TeamFilter { all, pending, role, department }

class OrgTeamScreen extends ConsumerStatefulWidget {
  const OrgTeamScreen({super.key});

  @override
  ConsumerState<OrgTeamScreen> createState() => _OrgTeamScreenState();
}

class _OrgTeamScreenState extends ConsumerState<OrgTeamScreen> {
  final _search = TextEditingController();
  String? _message;
  String? _error;
  bool _busy = false;
  _TeamFilter _filter = _TeamFilter.all;
  String? _filterRole;
  String? _filterDeptName;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _memberMatchesSearch(OrgMemberRow m, String q) {
    if (q.isEmpty) return true;
    final hay = [
      m.fullName,
      m.email,
      m.jobTitle,
      m.phone,
      m.role,
      ...m.departmentLabels,
    ].whereType<String>().join(' ').toLowerCase();
    return hay.contains(q);
  }

  List<OrgMemberRow> _filterMembers(List<OrgMemberRow> list) {
    final q = _search.text.trim().toLowerCase();
    var out = list.where((m) => _memberMatchesSearch(m, q)).toList();
    if (_filter == _TeamFilter.role && _filterRole != null) {
      out = out.where((m) => m.role == _filterRole).toList();
    }
    if (_filter == _TeamFilter.department && _filterDeptName != null) {
      out = out
          .where((m) => m.departmentLabels.contains(_filterDeptName))
          .toList();
    }
    if (_filter == _TeamFilter.pending) out = [];
    return out;
  }

  List<OrgInviteRow> _filterInvites(List<OrgInviteRow> list) {
    final q = _search.text.trim().toLowerCase();
    var out = list;
    if (q.isNotEmpty) {
      out = out
          .where((i) =>
              i.email.toLowerCase().contains(q) ||
              OrgRoles.label(i.role).toLowerCase().contains(q))
          .toList();
    }
    if (_filter == _TeamFilter.role && _filterRole != null) {
      out = out.where((i) => i.role == _filterRole).toList();
    }
    if (_filter == _TeamFilter.department) out = [];
    return out;
  }

  Future<void> _callMember(OrgMemberRow m) async {
    final raw = m.phone?.trim() ?? '';
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number on this member')),
        );
      }
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: digits));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer')),
        );
      }
    }
  }

  Future<void> _invite({required String email, required String role}) async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final res = await ref.read(supabaseClientProvider).functions.invoke(
        'invite-org-member',
        body: {
          'organization_id': org.id,
          'email': email,
          'role': role,
          'redirect_to': authRedirectTo('/accept-invite'),
        },
      );
      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map) map = Map<String, dynamic>.from(data);
      ref.invalidate(orgMembersProvider);
      ref.invalidate(orgInvitesProvider);
      if (map != null && map['error'] != null && map['status'] == null) {
        setState(() => _error = map!['error'].toString());
      } else {
        setState(() {
          _message = map?['message']?.toString() ?? 'Invite saved for $email';
        });
        await logOrgActivity(
          ref,
          action: 'invite_sent',
          summary: 'Invited $email as ${OrgRoles.label(role)}',
          metadata: {'email': email, 'role': role},
        );
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendInvite(OrgInviteRow invite) async {
    await _invite(email: invite.email, role: invite.role);
  }

  Future<void> _copyInviteLink(OrgInviteRow invite) async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(supabaseClientProvider).functions.invoke(
        'invite-org-member',
        body: {
          'organization_id': org.id,
          'email': invite.email,
          'role': invite.role,
          'redirect_to': authRedirectTo('/accept-invite'),
        },
      );
      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map) map = Map<String, dynamic>.from(data);
      final link = map?['action_link']?.toString();
      ref.invalidate(orgInvitesProvider);
      if (link != null && link.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Fresh invite link copied for ${invite.email}')),
          );
        }
      } else {
        setState(() => _error =
            map?['error']?.toString() ?? 'No link returned — try Resend');
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeInvite(OrgInviteRow invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel invite?'),
        content: Text('Revoke pending invite for ${invite.email}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel invite')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ref.read(supabaseClientProvider).functions.invoke(
        'revoke-org-invite',
        body: {'invite_id': invite.id},
      );
      final data = res.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      ref.invalidate(orgInvitesProvider);
      if (mounted) {
        setState(() => _message = 'Invite cancelled for ${invite.email}');
        await logOrgActivity(
          ref,
          action: 'invite_revoked',
          summary: 'Cancelled invite for ${invite.email}',
          metadata: {'email': invite.email, 'invite_id': invite.id},
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _removeMember(OrgMemberRow member) async {
    final org = ref.read(activeOrganizationProvider);
    final me = ref.read(currentUserProvider)?.id;
    if (org == null) return;
    if (member.userId == me) {
      setState(() => _error = 'You cannot remove yourself from here.');
      return;
    }
    if (member.role == OrgRoles.owner) {
      setState(() => _error = 'Cannot remove the organisation owner.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          'Remove ${member.fullName ?? 'this member'} '
          '(${OrgRoles.label(member.role)}) from ${org.name}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(supabaseClientProvider).rpc(
        'remove_org_member',
        params: {
          'p_organization_id': org.id,
          'p_user_id': member.userId,
        },
      );
      ref.invalidate(orgMembersProvider);
      ref.invalidate(orgInvitesProvider);
      ref.invalidate(orgDepartmentsProvider);
      ref.invalidate(orgDepartmentStatsProvider);
      if (mounted) {
        setState(() => _message = 'Member removed');
        final label = member.fullName?.trim().isNotEmpty == true
            ? member.fullName!.trim()
            : (member.email ?? 'member');
        await logOrgActivity(
          ref,
          action: 'member_removed',
          summary: 'Removed $label (${OrgRoles.label(member.role)})',
          metadata: {'user_id': member.userId, 'role': member.role},
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _editMember(OrgMemberRow member) async {
    final ok = await showOrgMemberEditDialog(
      context: context,
      ref: ref,
      member: member,
      onError: (msg) {
        if (mounted) setState(() => _error = msg);
      },
    );
    if (ok && mounted) {
      setState(() => _message = 'Member updated');
      final label = member.fullName?.trim().isNotEmpty == true
          ? member.fullName!.trim()
          : (member.email ?? 'member');
      await logOrgActivity(
        ref,
        action: 'member_updated',
        summary: 'Updated $label',
        metadata: {'user_id': member.userId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(orgMembersProvider);
    final invites = ref.watch(orgInvitesProvider);
    final depts = ref.watch(orgDepartmentsProvider).valueOrNull ?? [];
    final activeDepts = depts.where((d) => d.isActive).toList();
    final caps = ref.watch(orgCapabilitiesProvider);
    final canInvite = caps.isElevated;
    final me = ref.watch(currentUserProvider)?.id;
    final showMembers = _filter != _TeamFilter.pending;
    final showPending = _filter == _TeamFilter.all ||
        _filter == _TeamFilter.pending ||
        _filter == _TeamFilter.role;

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
          GlossSurfaces.fieldShell(
            child: TextField(
              controller: _search,
              style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
              cursorColor: GlossColors.navy,
              decoration: GlossSurfaces.compactField('Search team').copyWith(
                    hintText: 'Name, email, title, phone…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: GlossSurfaces.fieldGap),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OrgTeamFilterChip(
                  label: 'All',
                  selected: _filter == _TeamFilter.all,
                  onTap: () => setState(() {
                    _filter = _TeamFilter.all;
                    _filterRole = null;
                    _filterDeptName = null;
                  }),
                ),
                OrgTeamFilterChip(
                  label: 'Pending',
                  selected: _filter == _TeamFilter.pending,
                  onTap: () => setState(() {
                    _filter = _TeamFilter.pending;
                    _filterRole = null;
                    _filterDeptName = null;
                  }),
                ),
                OrgTeamFilterChip(
                  label: _filter == _TeamFilter.role && _filterRole != null
                      ? OrgRoles.label(_filterRole)
                      : 'Role',
                  selected: _filter == _TeamFilter.role,
                  onTap: () async {
                    final picked = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: GlossColors.sky,
                      builder: (ctx) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final r in OrgRoles.all)
                              ListTile(
                                title: Text(OrgRoles.label(r),
                                    style: GlossSurfaces.logoMark),
                                onTap: () => Navigator.pop(ctx, r),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _filter = _TeamFilter.role;
                        _filterRole = picked;
                        _filterDeptName = null;
                      });
                    }
                  },
                ),
                OrgTeamFilterChip(
                  label: _filter == _TeamFilter.department &&
                          _filterDeptName != null
                      ? _filterDeptName!
                      : 'Department',
                  selected: _filter == _TeamFilter.department,
                  onTap: () async {
                    if (activeDepts.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('No active departments yet')),
                      );
                      return;
                    }
                    final picked = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: GlossColors.sky,
                      builder: (ctx) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final d in activeDepts)
                              ListTile(
                                title: Text(d.name,
                                    style: GlossSurfaces.logoMark),
                                onTap: () => Navigator.pop(ctx, d.name),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _filter = _TeamFilter.department;
                        _filterDeptName = picked;
                        _filterRole = null;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          if (_error != null) ...[
            Text(_error!,
                style: GlossSurfaces.logoMark
                    .copyWith(color: GlossColors.danger)),
            const SizedBox(height: 8),
          ],
          if (_message != null) ...[
            Text(_message!, style: GlossSurfaces.logoAccent),
            const SizedBox(height: 8),
          ],
          if (showMembers) ...[
            Text(
              'MEMBERS',
              style: GlossSurfaces.logoAccent.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: GlossSurfaces.fieldGap),
            members.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(friendlyError(e)),
              data: (list) {
                final filtered = _filterMembers(list);
                if (list.isEmpty) {
                  return Text('No members found',
                      style: GlossSurfaces.logoAccent);
                }
                if (filtered.isEmpty) {
                  return Text('No members match this search or filter',
                      style: GlossSurfaces.logoAccent);
                }
                return Column(
                  children: [
                    for (final m in filtered)
                      OrgMemberTile(
                        member: m,
                        isMe: m.userId == me,
                        canManage: canInvite,
                        onTap: () => context.push('/org/team/${m.userId}'),
                        onCall: () => _callMember(m),
                        onEdit: () => _editMember(m),
                        onRemove: () => _removeMember(m),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          if (showPending && canInvite) ...[
            Text(
              'PENDING INVITES',
              style: GlossSurfaces.logoAccent.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: GlossSurfaces.fieldGap),
            invites.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text(friendlyError(e)),
              data: (list) {
                final filtered = _filterInvites(list);
                if (list.isEmpty) {
                  return Text('None', style: GlossSurfaces.logoAccent);
                }
                if (filtered.isEmpty) {
                  return Text('No pending invites match',
                      style: GlossSurfaces.logoAccent);
                }
                return Column(
                  children: [
                    for (final i in filtered)
                      OrgInviteTile(
                        invite: i,
                        canManage: canInvite,
                        onResend: () => _resendInvite(i),
                        onCopyLink: () => _copyInviteLink(i),
                        onCancel: () => _revokeInvite(i),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
