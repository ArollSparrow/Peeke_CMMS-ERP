import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.avatarUrl,
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
  final String? avatarUrl;
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
        avatarUrl: m['avatar_url'] as String?,
      );
    }).toList();
  } catch (_) {
    final rows = await client
        .from('organization_members')
        .select('id, user_id, role, full_name, phone, job_title, avatar_url')
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
        avatarUrl: m['avatar_url'] as String?,
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
          avatarUrl: m.avatarUrl,
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

  /// Cyan gloss plate shell — same visual language as member tiles.
  Widget _glossField({required Widget child}) {
    return GlossSurfaces.fieldShell(child: child);
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
        final status = map['status']?.toString();
        setState(() {
          _message = msg ?? 'Invite saved for $email';
          _actionLink = (status == 'invite_saved' &&
                  link != null &&
                  link.isNotEmpty)
              ? link
              : null;
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

  /// Cancel pending invite via edge function so residual Auth users are
  /// cleaned when the email is not a member of any organisation. That
  /// unblocks a later inviteUserByEmail so mail can reach the inbox again.
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
      // Shape + sky background from GlossTheme.dialogTheme.
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

  Future<String?> _uploadAvatar({
    required String orgId,
    required String userId,
  }) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final ext = (x.name.split('.').last).toLowerCase();
    final path = '$orgId/$userId.${ext.isEmpty ? 'jpg' : ext}';
    final client = ref.read(supabaseClientProvider);
    await client.storage.from('member-avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: x.mimeType ?? 'image/jpeg',
          ),
        );
    return client.storage.from('member-avatars').getPublicUrl(path);
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
    String? avatarUrl = member.avatarUrl;
    var avatarBusy = false;

    final maxH = MediaQuery.sizeOf(context).height * 0.78;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> pickAvatar() async {
              if (avatarBusy) return;
              setLocal(() => avatarBusy = true);
              try {
                final url = await _uploadAvatar(
                  orgId: org.id,
                  userId: member.userId,
                );
                if (url != null) {
                  setLocal(() => avatarUrl = url);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _error = friendlyError(e));
                }
              } finally {
                setLocal(() => avatarBusy = false);
              }
            }

            // Sky + radius from GlossTheme.dialogTheme; insetPadding is layout-only.
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Member details',
                              style: GlossSurfaces.logoMark.copyWith(
                                fontSize: 17,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Tap avatar to change photo — no camera icon / label.
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: avatarBusy ? null : pickAvatar,
                                  customBorder: const CircleBorder(),
                                  child: Tooltip(
                                    message: avatarBusy
                                        ? 'Uploading…'
                                        : 'Tap to change photo',
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 32,
                                          backgroundColor: GlossColors.sky
                                              .withValues(alpha: 0.9),
                                          backgroundImage: (avatarUrl != null &&
                                                  avatarUrl!.isNotEmpty)
                                              ? NetworkImage(avatarUrl!)
                                              : null,
                                          child: (avatarUrl == null ||
                                                  avatarUrl!.isEmpty)
                                              ? const Icon(
                                                  Icons.person_outline,
                                                  size: 32,
                                                  color: GlossColors.navy,
                                                )
                                              : null,
                                        ),
                                        if (avatarBusy)
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: GlossColors.navy
                                                  .withValues(alpha: 0.35),
                                            ),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: GlossColors.sky,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (member.email != null) ...[
                              const SizedBox(height: 8),
                              Text(member.email!,
                                  style: GlossSurfaces.tileMeta),
                            ],
                            const SizedBox(height: GlossSurfaces.fieldGap),
                            _glossField(
                              child: TextField(
                                controller: nameCtrl,
                                style: GlossSurfaces.logoMark
                                    .copyWith(fontSize: 13),
                                decoration:
                                    GlossSurfaces.compactField('Full name'),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(height: GlossSurfaces.fieldGap),
                            _glossField(
                              child: TextField(
                                controller: phoneCtrl,
                                style: GlossSurfaces.logoMark
                                    .copyWith(fontSize: 13),
                                decoration:
                                    GlossSurfaces.compactField('Phone'),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(height: GlossSurfaces.fieldGap),
                            _glossField(
                              child: TextField(
                                controller: jobCtrl,
                                style: GlossSurfaces.logoMark
                                    .copyWith(fontSize: 13),
                                decoration:
                                    GlossSurfaces.compactField('Job title'),
                              ),
                            ),
                            const SizedBox(height: GlossSurfaces.fieldGap),
                            if (member.role != OrgRoles.owner)
                              _glossField(
                                child: DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: role,
                                  isDense: true,
                                  isExpanded: true,
                                  iconSize: 18,
                                  style: GlossSurfaces.logoMark
                                      .copyWith(fontSize: 13),
                                  decoration:
                                      GlossSurfaces.compactField('Role'),
                                  items: [
                                    for (final r in OrgRoles.inviteChoices)
                                      DropdownMenuItem(
                                        value: r,
                                        child: Text(
                                          OrgRoles.label(r),
                                          style: GlossSurfaces.logoMark
                                              .copyWith(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setLocal(
                                      () => role = v ?? OrgRoles.technician),
                                ),
                              )
                            else
                              Text(
                                'Role: Owner / System Admin',
                                style: GlossSurfaces.logoMark
                                    .copyWith(fontSize: 13),
                              ),
                            const SizedBox(height: 12),
                            Text('Departments',
                                style: GlossSurfaces.logoMark
                                    .copyWith(fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to assign · long-press for HoD',
                              style: GlossSurfaces.logoAccent
                                  .copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: GlossSurfaces.fieldGap),
                            if (depts.isEmpty)
                              Text('No departments seeded yet.',
                                  style: GlossSurfaces.logoAccent)
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final d in depts)
                                    _deptChip(
                                      dept: d,
                                      selected:
                                          selectedDepts.contains(d.id),
                                      isHod: hodDepts.contains(d.id),
                                      onTap: () {
                                        setLocal(() {
                                          if (selectedDepts.contains(d.id)) {
                                            selectedDepts.remove(d.id);
                                            hodDepts.remove(d.id);
                                          } else {
                                            selectedDepts.add(d.id);
                                          }
                                        });
                                      },
                                      onLongPress: () {
                                        setLocal(() {
                                          if (!selectedDepts
                                              .contains(d.id)) {
                                            selectedDepts.add(d.id);
                                          }
                                          if (hodDepts.contains(d.id)) {
                                            hodDepts.remove(d.id);
                                          } else {
                                            hodDepts.add(d.id);
                                          }
                                        });
                                      },
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel',
                                style: GlossSurfaces.logoMark),
                          ),
                          const SizedBox(width: 8),
                          GlossSurfaces.glossCta(
                            label: 'SAVE',
                            onTap: () => Navigator.pop(ctx, true),
                            height: 42,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
          'p_avatar_url': avatarUrl,
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

  /// Department chips in member details: cyan gloss by default;
  /// navy gloss when selected (and HoD suffix in label).
  Widget _deptChip({
    required OrgDept dept,
    required bool selected,
    required bool isHod,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final label = isHod ? '${dept.name} · HoD' : dept.name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
    );
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

  Widget _memberCard(OrgMemberRow m, String? me, bool canManage) {
    final name = (m.fullName != null && m.fullName!.trim().isNotEmpty)
        ? m.fullName!.trim()
        : 'Team member';
    final title = (m.jobTitle != null && m.jobTitle!.trim().isNotEmpty)
        ? m.jobTitle!.trim()
        : null;
    final isMe = m.userId == me;
    final depts = m.departmentLabels;
    final hods = m.hodLabels;

    final nameParts = <String>[name];
    if (title != null) nameParts.add(title);
    if (isMe) nameParts.add('You');
    final nameLine = nameParts.join(' · ');

    final deptLabels = <String>[
      for (final d in depts) hods.contains(d) ? '$d(HoD)' : d,
      for (final h in hods)
        if (!depts.contains(h)) '$h(HoD)',
    ];

    // Meta: role first, then departments — always show role at a glance.
    final metaParts = <String>[OrgRoles.label(m.role)];
    if (deptLabels.isNotEmpty) metaParts.addAll(deptLabels);
    final metaLine = metaParts.join(' · ');

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
                  // Meta (role · depts) on top — deeper teal
                  Row(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
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
                  // Navy name line on bottom
                  Text(
                    nameLine,
                    style: GlossSurfaces.tileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: GlossSurfaces.logoMark),
                  ),
                  if (!isMe && m.role != OrgRoles.owner)
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove', style: GlossSurfaces.logoMark),
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
                  if (v == 'cancel') _revokeInvite(i);
                },
                itemBuilder: (_) => [
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
        onTap: _invite,
        busy: _busy,
      ),
    );
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
          Center(
            child: Image.asset(
              'assets/branding/peeke_icon.png',
              height: 88,
              width: 88,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'Peeke',
                style: GlossSurfaces.logoMark.copyWith(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                'Email may be delayed — share this link (WhatsApp / SMS):',
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
                'Only owners, system admins, and elevated roles can manage the team.',
                style: GlossSurfaces.logoAccent,
              ),
            ),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(friendlyError(e)),
            data: (list) {
              if (list.isEmpty) {
                return Text('No members found',
                    style: GlossSurfaces.logoAccent);
              }
              return Column(
                children: [
                  for (final m in list) _memberCard(m, me, canInvite),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
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
              if (list.isEmpty) {
                return Text('None', style: GlossSurfaces.logoAccent);
              }
              return Column(
                children: [
                  for (final i in list) _inviteTile(i, canInvite),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
