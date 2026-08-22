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
import 'org_team_models.dart';

export 'org_team_models.dart';

/// Client-side email check aligned with invite-org-member EMAIL_RE.
final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

enum _TeamFilter { all, pending, role, department }

class OrgTeamScreen extends ConsumerStatefulWidget {
  const OrgTeamScreen({super.key});

  @override
  ConsumerState<OrgTeamScreen> createState() => _OrgTeamScreenState();
}

class _OrgTeamScreenState extends ConsumerState<OrgTeamScreen> {
  final _email = TextEditingController();
  final _search = TextEditingController();
  String _role = OrgRoles.technician;
  bool _busy = false;
  String? _message;
  String? _error;
  String? _actionLink;

  _TeamFilter _filter = _TeamFilter.all;
  String? _filterRole;
  String? _filterDeptName;

  @override
  void dispose() {
    _email.dispose();
    _search.dispose();
    super.dispose();
  }

  Widget _glossField({required Widget child}) {
    return GlossSurfaces.fieldShell(child: child);
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
    if (_filter == _TeamFilter.pending) {
      out = [];
    }
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
    if (_filter == _TeamFilter.department) {
      out = [];
    }
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
    if (digits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number is not dialable')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: digits);
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer')),
        );
      }
    }
  }

  Future<void> _invite({String? emailOverride, String? roleOverride}) async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    final email = (emailOverride ?? _email.text).trim().toLowerCase();
    final role = roleOverride ?? _role;
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = 'Enter a valid work email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _actionLink = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke(
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

      if (map == null) {
        setState(() => _message = 'Invite processed.');
      } else if (map['error'] != null &&
          map['status'] != 'invite_saved' &&
          map['status'] == null) {
        setState(() => _error = map!['error'].toString());
      } else {
        final msg = map['message']?.toString();
        final link = map['action_link']?.toString();
        setState(() {
          _message = msg ?? 'Invite saved for $email';
          _actionLink =
              (link != null && link.isNotEmpty) ? link : null;
        });
        if (emailOverride == null) _email.clear();
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyText(String link, {String snack = 'Invite link copied'}) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snack)),
      );
    }
  }

  Future<void> _copyLink() async {
    final link = _actionLink;
    if (link == null) return;
    await _copyText(link, snack: 'Invite link copied — share via WhatsApp/SMS');
  }

  Future<void> _resendInvite(OrgInviteRow invite) async {
    await _invite(emailOverride: invite.email, roleOverride: invite.role);
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
        setState(() => _actionLink = link);
        await _copyText(link,
            snack: 'Fresh invite link copied for ${invite.email}');
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
        content: Text(
          'Revoke pending invite for ${invite.email}?\n\n'
          'Any leftover Auth account that is not a member of any organisation '
          'will also be removed so a fresh invite can reach the inbox.',
        ),
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
        final cleaned = data is Map && data['auth_user_deleted'] == true;
        setState(() {
          _message = cleaned
              ? 'Invite cancelled for ${invite.email} (residual Auth user cleaned)'
              : 'Invite cancelled for ${invite.email}';
          _actionLink = null;
        });
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
          '(${OrgRoles.label(member.role)}) from ${org.name}?\n\n'
          'Their role, departments, and invites for this organisation '
          'will be cleared completely.',
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
        setState(() {
          _message = 'Member removed — all organisation traces cleared';
          _actionLink = null;
        });
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
    }
  }

  Widget _avatarDisc(String? url) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GlossColors.sky,
        border: Border.all(
          color: GlossColors.navy.withValues(alpha: 0.28),
          width: 1.5,
        ),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? const Icon(Icons.person_outline,
              color: GlossColors.navy, size: 17)
          : null,
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GlossSurfaces.tileRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration:
                selected ? GlossSurfaces.navyPlate : GlossSurfaces.plate,
            child: Text(
              label,
              style: GlossSurfaces.tileName.copyWith(
                color: selected ? GlossColors.sky : GlossColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberCard(OrgMemberRow m, String? me, bool canManage) {
    final name = (m.fullName != null && m.fullName!.trim().isNotEmpty)
        ? m.fullName!.trim()
        : 'Team member';
    final title = (m.jobTitle != null && m.jobTitle!.trim().isNotEmpty)
        ? m.jobTitle!.trim()
        : null;
    final isMe = m.userId == me;
    final hasPhone = (m.phone != null && m.phone!.trim().isNotEmpty);

    final nameParts = <String>[name];
    if (isMe) nameParts.add('You');
    final nameLine = nameParts.join(' · ');

    // Meta: job title only (departments stay on edit dialog / Departments).
    // Elevated also sees org role for admin scanability.
    final metaParts = <String>[];
    if (canManage) metaParts.add(OrgRoles.label(m.role));
    if (title != null) metaParts.add(title);
    final metaLine = metaParts.isEmpty ? '—' : metaParts.join(' · ');

    return Container(
      width: double.infinity,
      height: GlossSurfaces.tileMinHeight,
      margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
      decoration: GlossSurfaces.plate,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _avatarDisc(m.avatarUrl),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        title != null
                            ? Icons.work_outline
                            : Icons.badge_outlined,
                        size: 12,
                        color: GlossColors.tealDeep,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          metaLine,
                          style: GlossSurfaces.tileMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    nameLine,
                    style: GlossSurfaces.tileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasPhone)
              IconButton(
                tooltip: 'Call ${m.phone}',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  Icons.call_outlined,
                  color: GlossColors.tealDeep,
                  size: 20,
                ),
                onPressed: () => _callMember(m),
              ),
            if (canManage)
              PopupMenuButton<String>(
                tooltip: 'Actions',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  Icons.more_vert,
                  color: GlossColors.tealDeep,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(GlossSurfaces.tileRadius),
                ),
                color: GlossColors.sky,
                onSelected: (value) {
                  if (value == 'edit') _editMember(m);
                  if (value == 'remove') _removeMember(m);
                  if (value == 'call') _callMember(m);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: GlossSurfaces.logoMark),
                  ),
                  if (hasPhone)
                    PopupMenuItem(
                      value: 'call',
                      child: Text('Call', style: GlossSurfaces.logoMark),
                    ),
                  if (!isMe && m.role != OrgRoles.owner)
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove', style: GlossSurfaces.logoMark),
                    ),
                ],
              )
            else if (!hasPhone)
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _inviteTile(OrgInviteRow i, bool canManage) {
    return Container(
      width: double.infinity,
      height: GlossSurfaces.tileMinHeight,
      margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
      decoration: GlossSurfaces.plate,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlossColors.sky,
                border: Border.all(
                  color: GlossColors.navy.withValues(alpha: 0.28),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.mail_outline,
                color: GlossColors.tealDeep,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${OrgRoles.label(i.role)} · pending',
                    style: GlossSurfaces.tileMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    i.email,
                    style: GlossSurfaces.tileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (canManage)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  Icons.more_vert,
                  color: GlossColors.tealDeep,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(GlossSurfaces.tileRadius),
                ),
                color: GlossColors.sky,
                onSelected: (v) {
                  if (v == 'resend') _resendInvite(i);
                  if (v == 'copy') _copyInviteLink(i);
                  if (v == 'cancel') _revokeInvite(i);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'resend',
                    child: Text('Resend invite',
                        style: GlossSurfaces.logoMark),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Text('Copy invite link',
                        style: GlossSurfaces.logoMark),
                  ),
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel invite',
                        style: GlossSurfaces.logoMark),
                  ),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _sendInviteButton() {
    return Align(
      alignment: Alignment.center,
      child: GlossSurfaces.glossCta(
        label: 'SEND INVITE',
        onTap: () => _invite(),
        busy: _busy,
      ),
    );
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
        title: const Text('Team'),
        actions: [
          IconButton(
            tooltip: 'Roles',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => context.push('/org/roles'),
          ),
          if (canInvite)
            IconButton(
              tooltip: 'Departments',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => context.push('/org/departments'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Center(
            child: Image.asset(
              'assets/branding/peeke_icon.png',
              height: 72,
              width: 72,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'Peeke',
                style: GlossSurfaces.logoMark.copyWith(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _glossField(
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
                _filterChip(
                  label: 'All',
                  selected: _filter == _TeamFilter.all,
                  onTap: () => setState(() {
                    _filter = _TeamFilter.all;
                    _filterRole = null;
                    _filterDeptName = null;
                  }),
                ),
                _filterChip(
                  label: 'Pending',
                  selected: _filter == _TeamFilter.pending,
                  onTap: () => setState(() {
                    _filter = _TeamFilter.pending;
                    _filterRole = null;
                    _filterDeptName = null;
                  }),
                ),
                _filterChip(
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
                _filterChip(
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
          if (canInvite) ...[
            _glossField(
              child: TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
                cursorColor: GlossColors.navy,
                decoration: GlossSurfaces.compactField('Work email').copyWith(
                      hintText: 'colleague@company.com',
                    ),
              ),
            ),
            const SizedBox(height: GlossSurfaces.fieldGap),
            _glossField(
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _role,
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
                onChanged: (v) =>
                    setState(() => _role = v ?? OrgRoles.technician),
              ),
            ),
            const SizedBox(height: 12),
            _sendInviteButton(),
            if (_error != null) ...[
              const SizedBox(height: GlossSurfaces.fieldGap),
              Text(_error!,
                  style: GlossSurfaces.logoMark
                      .copyWith(color: GlossColors.danger)),
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
                label: Text('Copy invite link',
                    style: GlossSurfaces.logoMark),
              ),
            ],
            const SizedBox(height: 20),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Directory is open to all members. Only elevated roles can invite or edit.',
                style: GlossSurfaces.logoAccent,
              ),
            ),
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/org/team/${m.userId}'),
                        child: _memberCard(m, me, canInvite),
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
                    for (final i in filtered) _inviteTile(i, canInvite),
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
