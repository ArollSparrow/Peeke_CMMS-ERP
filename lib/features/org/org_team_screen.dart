import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import '../auth/login_screen.dart' show authRedirectTo;
import 'org_providers.dart';
import 'org_roles.dart';

class OrgMemberRow {
  const OrgMemberRow({
    required this.id,
    required this.userId,
    required this.role,
    this.email,
    this.fullName,
    this.phone,
    this.jobTitle,
  });
  final String id;
  final String userId;
  final String role;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? jobTitle;
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

final orgMembersProvider =
    FutureProvider.autoDispose<List<OrgMemberRow>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client.rpc(
      'list_org_team',
      params: {'p_organization_id': org.id},
    );
    return (rows as List).map((e) {
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
    return (rows as List).map((e) {
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
          'Remove ${member.fullName ?? member.email ?? 'this member'} '
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
              title: const Text('Member details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (member.email != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          member.email!,
                          style: const TextStyle(
                              color: GlossColors.teal, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: jobCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Job title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (member.role != OrgRoles.owner)
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: [
                          for (final r in OrgRoles.inviteChoices)
                            DropdownMenuItem(
                              value: r,
                              child: Text(OrgRoles.label(r)),
                            ),
                        ],
                        onChanged: (v) =>
                            setLocal(() => role = v ?? OrgRoles.technician),
                      )
                    else
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Role: Owner / System Admin (fixed)',
                          style: TextStyle(color: GlossColors.navy),
                        ),
                      ),
                  ],
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
      await ref.read(supabaseClientProvider).rpc(
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
      ref.invalidate(orgMembersProvider);
      if (mounted) setState(() => _message = 'Member updated');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
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
            'Invite by work email. Choose a role (default Technician). '
            'Invitees open Accept invitation → full name, phone, password. '
            'Edit personal details and role after they join. '
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
                      child: ListTile(
                        title: Text(
                          m.userId == me
                              ? '${m.fullName ?? m.email ?? 'You'} (You)'
                              : (m.fullName ??
                                  m.email ??
                                  (m.userId.length > 8
                                      ? '…${m.userId.substring(m.userId.length - 8)}'
                                      : m.userId)),
                          style: const TextStyle(color: GlossColors.navy),
                        ),
                        subtitle: Text(
                          [
                            OrgRoles.label(m.role),
                            if (m.email != null && m.fullName != null) m.email!,
                            if (m.jobTitle != null && m.jobTitle!.isNotEmpty)
                              m.jobTitle!,
                            if (m.phone != null && m.phone!.isNotEmpty) m.phone!,
                          ].join(' · '),
                          style: const TextStyle(
                              color: GlossColors.teal, fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: canInvite
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit details / role',
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
