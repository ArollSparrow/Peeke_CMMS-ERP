import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import '../auth/login_screen.dart' show authRedirectTo;
import 'org_providers.dart';
import 'org_roles.dart';

const _cardRadius = 20.0;

class OrgMemberRow {
  const OrgMemberRow({
    required this.id,
    required this.userId,
    required this.role,
    this.email,
    this.fullName,
    this.phone,
    this.jobTitle,
    this.departmentLabels = const [],
    this.hodLabels = const [],
  });
  final String id;
  final String userId;
  final String role;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? jobTitle;
  final List<String> departmentLabels;
  final List<String> hodLabels;
}

class OrgInviteRow {
  const OrgInviteRow({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
  });
  final String id;
  final String email;
  final String role;
  final String status;
}

class OrgDept {
  const OrgDept({
    required this.id,
    required this.code,
    required this.name,
  });
  final String id;
  final String code;
  final String name;
}

final orgDepartmentsProvider =
    FutureProvider.autoDispose<List<OrgDept>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  final client = ref.watch(supabaseClientProvider);

  Future<List<OrgDept>> load() async {
    final rows = await client
        .from('organization_departments')
        .select('id, code, name, sort_order')
        .eq('organization_id', org.id)
        .order('sort_order');
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OrgDept(
        id: m['id'] as String,
        code: m['code'] as String,
        name: m['name'] as String? ?? OrgDepartments.label(m['code'] as String),
      );
    }).toList();
  }

  var list = await load();
  if (list.isEmpty) {
    try {
      await client.rpc(
        'seed_organization_departments',
        params: {'p_org_id': org.id},
      );
      list = await load();
    } catch (_) {}
  }
  return list;
});

final orgMembersProvider =
    FutureProvider.autoDispose<List<OrgMemberRow>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final depts = await ref.watch(orgDepartmentsProvider.future);
  final deptById = {for (final d in depts) d.id: d};

  List<OrgMemberRow> base = [];
  try {
    final rows = await client.rpc(
      'list_org_team',
      params: {'p_organization_id': org.id},
    );
    base = (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OrgMemberRow(
        id: m['membership_id'] as String,
        userId: m['user_id'] as String,
        role: OrgRoles.normalize(m['role'] as String?),
        email: m['email'] as String?,
        fullName: m['full_name'] as String?,
        phone: m['phone'] as String?,
        jobTitle: m['job_title'] as String?,
      );
    }).toList();
  } catch (_) {
    final rows = await client
        .from('organization_members')
        .select('id, user_id, role, full_name, phone, job_title')
        .eq('organization_id', org.id);
    base = (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OrgMemberRow(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        role: OrgRoles.normalize(m['role'] as String?),
        fullName: m['full_name'] as String?,
        phone: m['phone'] as String?,
        jobTitle: m['job_title'] as String?,
      );
    }).toList();
  }

  final mdRows = await client
      .from('organization_member_departments')
      .select('user_id, department_id')
      .eq('organization_id', org.id);
  final hodRows = await client
      .from('organization_department_heads')
      .select('user_id, department_id')
      .eq('organization_id', org.id);

  final memberDepts = <String, List<String>>{};
  for (final e in (mdRows as List)) {
    final m = Map<String, dynamic>.from(e as Map);
    final uid = m['user_id'] as String;
    final did = m['department_id'] as String;
    final name = deptById[did]?.name;
    if (name == null) continue;
    memberDepts.putIfAbsent(uid, () => []).add(name);
  }
  final hodDepts = <String, List<String>>{};
  for (final e in (hodRows as List)) {
    final m = Map<String, dynamic>.from(e as Map);
    final uid = m['user_id'] as String;
    final did = m['department_id'] as String;
    final name = deptById[did]?.name;
    if (name == null) continue;
    hodDepts.putIfAbsent(uid, () => []).add(name);
  }

  return base
      .map(
        (m) => OrgMemberRow(
          id: m.id,
          userId: m.userId,
          role: m.role,
          email: m.email,
          fullName: m.fullName,
          phone: m.phone,
          jobTitle: m.jobTitle,
          departmentLabels: memberDepts[m.userId] ?? const [],
          hodLabels: hodDepts[m.userId] ?? const [],
        ),
      )
      .toList();
});

final orgInvitesProvider =
    FutureProvider.autoDispose<List<OrgInviteRow>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('organization_invites')
      .select('id, email, role, status')
      .eq('organization_id', org.id)
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  return (rows as List).map((e) {
    final m = Map<String, dynamic>.from(e as Map);
    return OrgInviteRow(
      id: m['id'] as String,
      email: m['email'] as String,
      role: OrgRoles.normalize(m['role'] as String?),
      status: m['status'] as String? ?? 'pending',
    );
  }).toList();
});

class OrgTeamScreen extends ConsumerStatefulWidget {
  const OrgTeamScreen({super.key});

  @override
  ConsumerState<OrgTeamScreen> createState() => _OrgTeamScreenState();
}

class _OrgTeamScreenState extends ConsumerState<OrgTeamScreen> {
  final _email = TextEditingController();
  String _role = OrgRoles.technician;
  bool _busy = false;
  String? _message;
  String? _error;
  String? _actionLink;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
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
          'role': _role,
          'redirect_to': authRedirectTo('/accept-invite'),
        },
      );

      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }

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
          _actionLink = (link != null && link.isNotEmpty) ? link : null;
        });
        _email.clear();
      }
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
      await ref.read(supabaseClientProvider).rpc(
        'revoke_org_invite',
        params: {'p_invite_id': invite.id},
      );
      ref.invalidate(orgInvitesProvider);
      if (mounted) {
        setState(() => _message = 'Invite cancelled for ${invite.email}');
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
      if (mounted) setState(() => _message = 'Member removed');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _editMember(OrgMemberRow member) async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    final client = ref.read(supabaseClientProvider);

    final depts = await ref.read(orgDepartmentsProvider.future);

    final mdRows = await client
        .from('organization_member_departments')
        .select('department_id')
        .eq('organization_id', org.id)
        .eq('user_id', member.userId);
    final hodRows = await client
        .from('organization_department_heads')
        .select('department_id')
        .eq('organization_id', org.id)
        .eq('user_id', member.userId);

    final selectedDepts = <String>{
      for (final e in (mdRows as List))
        Map<String, dynamic>.from(e as Map)['department_id'] as String,
    };
    final hodDepts = <String>{
      for (final e in (hodRows as List))
        Map<String, dynamic>.from(e as Map)['department_id'] as String,
    };

    final nameCtrl = TextEditingController(text: member.fullName ?? '');
    final phoneCtrl = TextEditingController(text: member.phone ?? '');
    final jobCtrl = TextEditingController(text: member.jobTitle ?? '');
    var role = member.role == OrgRoles.owner
        ? OrgRoles.owner
        : OrgRoles.normalize(member.role);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
              title: const Text('Member details'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (member.email != null) ...[
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 12,
                            color: GlossColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          member.email!,
                          style: const TextStyle(
                            color: GlossColors.navy,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: jobCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Job title'),
                      ),
                      const SizedBox(height: 12),
                      if (member.role != OrgRoles.owner)
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration:
                              const InputDecoration(labelText: 'Role'),
                          items: [
                            for (final r in OrgRoles.inviteChoices)
                              DropdownMenuItem(
                                value: r,
                                child: Text(OrgRoles.label(r)),
                              ),
                          ],
                          onChanged: (v) => setLocal(
                              () => role = v ?? OrgRoles.technician),
                        )
                      else
                        const Text(
                          'Role: Owner / System Admin (fixed)',
                          style: TextStyle(color: GlossColors.navy),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Departments',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: GlossColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Any role (Technician, Supervisor, Officer, …) can '
                        'belong to one or more departments. '
                        '“Head of department” is optional — only enable it '
                        'if they lead that department. It is separate from '
                        'the HoD job role.',
                        style: TextStyle(
                          fontSize: 12,
                          color: GlossColors.teal,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (depts.isEmpty)
                        const Text(
                          'No departments seeded yet.',
                          style: TextStyle(color: GlossColors.teal),
                        )
                      else
                        for (final d in depts) ...[
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              d.name,
                              style: const TextStyle(
                                color: GlossColors.navy,
                                fontSize: 14,
                              ),
                            ),
                            value: selectedDepts.contains(d.id),
                            activeColor: GlossColors.teal,
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selectedDepts.add(d.id);
                                } else {
                                  selectedDepts.remove(d.id);
                                  hodDepts.remove(d.id);
                                }
                              });
                            },
                          ),
                          if (selectedDepts.contains(d.id))
                            Padding(
                              padding: const EdgeInsets.only(left: 28, bottom: 4),
                              child: SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Head of this department',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: GlossColors.navy,
                                  ),
                                ),
                                value: hodDepts.contains(d.id),
                                activeColor: GlossColors.teal,
                                onChanged: (v) {
                                  setLocal(() {
                                    if (v) {
                                      hodDepts.add(d.id);
                                    } else {
                                      hodDepts.remove(d.id);
                                    }
                                  });
                                },
                              ),
                            ),
                        ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    try {
      await client.rpc(
        'update_org_member_details',
        params: {
          'p_organization_id': org.id,
          'p_user_id': member.userId,
          'p_role': member.role == OrgRoles.owner ? null : role,
          'p_full_name': nameCtrl.text.trim(),
          'p_phone': phoneCtrl.text.trim(),
          'p_job_title': jobCtrl.text.trim(),
        },
      );
      await client.rpc(
        'set_org_member_departments',
        params: {
          'p_organization_id': org.id,
          'p_user_id': member.userId,
          'p_department_ids': selectedDepts.toList(),
          'p_hod_department_ids': hodDepts.toList(),
        },
      );
      ref.invalidate(orgMembersProvider);
      ref.invalidate(orgDepartmentsProvider);
      if (mounted) setState(() => _message = 'Member updated');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  /// Single-line card label: name (+ job title). Role/dept/email only in edit.
  String _memberCardLine(OrgMemberRow m, String? me) {
    final name = (m.fullName != null && m.fullName!.trim().isNotEmpty)
        ? m.fullName!.trim()
        : 'Team member';
    final title = (m.jobTitle != null && m.jobTitle!.trim().isNotEmpty)
        ? m.jobTitle!.trim()
        : null;
    final core = title == null ? name : '$name · $title';
    if (m.userId == me) return '$core (You)';
    return core;
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(orgMembersProvider);
    final invites = ref.watch(orgInvitesProvider);
    final caps = ref.watch(orgCapabilitiesProvider);
    final canInvite = caps.isElevated;
    final me = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: GlossColors.sky,
      appBar: AppBar(title: const Text('Team')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Invite by work email and role. Edit a member for departments '
            '(any role can belong; head-of-department is optional). '
            'Owner is System Admin and HoD of IT by default.',
            style: TextStyle(color: GlossColors.teal, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (canInvite) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: GlossColors.navy),
              decoration: const InputDecoration(
                labelText: 'Work email',
                hintText: 'colleague@company.com',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r in OrgRoles.inviteChoices)
                  DropdownMenuItem(
                    value: r,
                    child: Text(OrgRoles.label(r)),
                  ),
              ],
              onChanged: (v) =>
                  setState(() => _role = v ?? OrgRoles.technician),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _invite,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GlossColors.sky),
                    )
                  : const Text('Send invite'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: GlossColors.danger)),
            ],
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: const TextStyle(color: GlossColors.teal)),
            ],
            if (_actionLink != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Share this link (WhatsApp / SMS):',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: GlossColors.navy),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _actionLink!,
                style: const TextStyle(fontSize: 12, color: GlossColors.teal),
              ),
              TextButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy invite link'),
              ),
            ],
            const SizedBox(height: 24),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Only owners, system admins, and elevated roles can manage the team.',
                style: TextStyle(color: GlossColors.teal),
              ),
            ),
          const Text(
            'MEMBERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: GlossColors.teal,
            ),
          ),
          const SizedBox(height: 8),
          members.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(friendlyError(e)),
            data: (list) {
              if (list.isEmpty) {
                return const Text('No members found',
                    style: TextStyle(color: GlossColors.teal));
              }
              return Column(
                children: [
                  for (final m in list)
                    Card(
                      elevation: 0,
                      color: Colors.white.withValues(alpha: 0.72),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                        side: BorderSide(
                          color: GlossColors.teal.withValues(alpha: 0.35),
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: Text(
                          _memberCardLine(m, me),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GlossColors.navy,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        trailing: canInvite
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit details / departments',
                                    icon: const Icon(Icons.edit_outlined),
                                    color: GlossColors.navy,
                                    onPressed: () => _editMember(m),
                                  ),
                                  if (m.userId != me &&
                                      m.role != OrgRoles.owner)
                                    IconButton(
                                      tooltip: 'Remove',
                                      icon: const Icon(
                                          Icons.person_remove_outlined),
                                      color: GlossColors.navy,
                                      onPressed: () => _removeMember(m),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'PENDING INVITES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: GlossColors.teal,
            ),
          ),
          const SizedBox(height: 8),
          invites.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text(friendlyError(e)),
            data: (list) {
              if (list.isEmpty) {
                return const Text('None',
                    style: TextStyle(color: GlossColors.teal));
              }
              return Column(
                children: [
                  for (final i in list)
                    Card(
                      elevation: 0,
                      color: Colors.white.withValues(alpha: 0.72),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_cardRadius),
                        side: BorderSide(
                          color: GlossColors.teal.withValues(alpha: 0.35),
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(i.email),
                        subtitle: Text(
                            '${OrgRoles.label(i.role)} · ${i.status}'),
                        trailing: canInvite
                            ? IconButton(
                                tooltip: 'Cancel invite',
                                icon: const Icon(Icons.cancel_outlined),
                                color: GlossColors.navy,
                                onPressed: () => _revokeInvite(i),
                              )
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
