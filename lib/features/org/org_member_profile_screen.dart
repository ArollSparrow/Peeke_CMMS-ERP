import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import 'member_edit_dialog.dart';
import 'org_providers.dart';
import 'org_roles.dart';
import 'org_team_models.dart';

/// Full-screen member profile. All members can view; self can edit contact
/// fields; elevated can open the full admin edit dialog.
class OrgMemberProfileScreen extends ConsumerStatefulWidget {
  const OrgMemberProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<OrgMemberProfileScreen> createState() =>
      _OrgMemberProfileScreenState();
}

class _OrgMemberProfileScreenState
    extends ConsumerState<OrgMemberProfileScreen> {
  bool _busy = false;
  String? _error;
  String? _message;

  OrgMemberRow? _find(List<OrgMemberRow> list) {
    for (final m in list) {
      if (m.userId == widget.userId) return m;
    }
    return null;
  }

  Future<void> _call(OrgMemberRow m) async {
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

  Future<void> _adminEdit(OrgMemberRow m) async {
    final ok = await showOrgMemberEditDialog(
      context: context,
      ref: ref,
      member: m,
      onError: (msg) {
        if (mounted) setState(() => _error = msg);
      },
    );
    if (ok && mounted) {
      setState(() => _message = 'Member updated');
      final label = m.fullName?.trim().isNotEmpty == true
          ? m.fullName!.trim()
          : (m.email ?? 'member');
      await logOrgActivity(
        ref,
        action: 'member_updated',
        summary: 'Updated $label',
        metadata: {'user_id': m.userId},
      );
    }
  }

  Future<void> _selfServeEdit(OrgMemberRow m) async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    final nameCtrl = TextEditingController(text: m.fullName ?? '');
    final phoneCtrl = TextEditingController(text: m.phone ?? '');
    final jobCtrl = TextEditingController(text: m.jobTitle ?? '');
    var avatarUrl = m.avatarUrl;
    var avatarBusy = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> pickAvatar() async {
              if (avatarBusy) return;
              setLocal(() => avatarBusy = true);
              try {
                final url = await uploadMemberAvatar(
                  client: ref.read(supabaseClientProvider),
                  orgId: org.id,
                  userId: m.userId,
                );
                if (url != null) setLocal(() => avatarUrl = url);
              } catch (e) {
                if (mounted) setState(() => _error = friendlyError(e));
              } finally {
                setLocal(() => avatarBusy = false);
              }
            }

            return AlertDialog(
              title: Text('Edit your profile', style: GlossSurfaces.logoMark),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: avatarBusy ? null : pickAvatar,
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: GlossColors.sky,
                          backgroundImage: (avatarUrl != null &&
                                  avatarUrl!.isNotEmpty)
                              ? NetworkImage(avatarUrl!)
                              : null,
                          child: (avatarUrl == null || avatarUrl!.isEmpty)
                              ? const Icon(Icons.person_outline,
                                  size: 36, color: GlossColors.navy)
                              : (avatarBusy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : null),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Tap photo to change',
                        style: GlossSurfaces.logoAccent.copyWith(fontSize: 11)),
                    const SizedBox(height: GlossSurfaces.fieldGap),
                    GlossSurfaces.fieldShell(
                      child: TextField(
                        controller: nameCtrl,
                        style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
                        decoration: GlossSurfaces.compactField('Full name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(height: GlossSurfaces.fieldGap),
                    GlossSurfaces.fieldShell(
                      child: TextField(
                        controller: phoneCtrl,
                        style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
                        decoration: GlossSurfaces.compactField('Phone'),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(height: GlossSurfaces.fieldGap),
                    GlossSurfaces.fieldShell(
                      child: TextField(
                        controller: jobCtrl,
                        style: GlossSurfaces.logoMark.copyWith(fontSize: 13),
                        decoration: GlossSurfaces.compactField('Job title'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Role and departments are managed by elevated roles.',
                      style: GlossSurfaces.logoAccent.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: GlossSurfaces.logoMark),
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
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(supabaseClientProvider).rpc(
        'update_org_member_details',
        params: {
          'p_organization_id': org.id,
          'p_user_id': m.userId,
          'p_role': null,
          'p_full_name': nameCtrl.text.trim(),
          'p_phone': phoneCtrl.text.trim(),
          'p_job_title': jobCtrl.text.trim(),
          'p_avatar_url': avatarUrl,
        },
      );
      ref.invalidate(orgMembersProvider);
      if (mounted) setState(() => _message = 'Profile updated');
      await logOrgActivity(
        ref,
        action: 'member_updated',
        summary: 'Updated own profile',
        metadata: {'user_id': m.userId, 'self': true},
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transferOwnership(OrgMemberRow m) async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    final name = (m.fullName != null && m.fullName!.trim().isNotEmpty)
        ? m.fullName!.trim()
        : (m.email ?? 'this member');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer ownership?'),
        content: Text(
          'Make $name the organisation owner of ${org.name}?\n\n'
          'You will become System Admin. Only one owner is allowed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(supabaseClientProvider).rpc(
        'transfer_org_ownership',
        params: {
          'p_organization_id': org.id,
          'p_new_owner_user_id': m.userId,
        },
      );
      ref.invalidate(orgMembersProvider);
      ref.invalidate(activeMembershipRoleProvider);
      ref.invalidate(orgActivityProvider);
      if (mounted) {
        setState(() => _message = 'Ownership transferred to $name');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value, {IconData? icon}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: GlossSurfaces.fieldGap),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: GlossSurfaces.plate,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: GlossColors.tealDeep),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GlossSurfaces.tileMeta),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GlossSurfaces.tileName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(orgMembersProvider);
    final me = ref.watch(currentUserProvider)?.id;
    final caps = ref.watch(orgCapabilitiesProvider);
    final elevated = caps.isElevated;
    final isOwner = caps.isOwner;
    final isSelf = me != null && me == widget.userId;

    return Scaffold(
      backgroundColor: GlossColors.sky,
      // Fully opaque so no prior route (e.g. login) can show through on web.
      appBar: AppBar(
        title: Text(isSelf ? 'My profile' : 'Member'),
        actions: [
          members.maybeWhen(
            data: (list) {
              final m = _find(list);
              if (m == null) return const SizedBox.shrink();
              if (isSelf) {
                return IconButton(
                  tooltip: 'Edit profile',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _busy ? null : () => _selfServeEdit(m),
                );
              }
              if (elevated) {
                return IconButton(
                  tooltip: 'Edit member',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _adminEdit(m),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ColoredBox(
        color: GlossColors.sky,
        child: members.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(friendlyError(e)),
          ),
          data: (list) {
            final m = _find(list);
            if (m == null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Member not found in this organisation.',
                  style: GlossSurfaces.logoAccent,
                ),
              );
            }
            final name = (m.fullName != null && m.fullName!.trim().isNotEmpty)
                ? m.fullName!.trim()
                : 'Team member';
            final title = (m.jobTitle != null && m.jobTitle!.trim().isNotEmpty)
                ? m.jobTitle!.trim()
                : '—';
            final phone = (m.phone != null && m.phone!.trim().isNotEmpty)
                ? m.phone!.trim()
                : '—';
            final email = (m.email != null && m.email!.trim().isNotEmpty)
                ? m.email!.trim()
                : '—';
            final depts = m.departmentLabels;
            final hod = m.hodLabels;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: GlossColors.sky,
                    backgroundImage: (m.avatarUrl != null &&
                            m.avatarUrl!.isNotEmpty)
                        ? NetworkImage(m.avatarUrl!)
                        : null,
                    child: (m.avatarUrl == null || m.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person_outline,
                            size: 44, color: GlossColors.navy)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    name + (isSelf ? ' · You' : ''),
                    style: GlossSurfaces.logoMark.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    OrgRoles.label(m.role),
                    style: GlossSurfaces.logoAccent,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: GlossSurfaces.logoMark
                          .copyWith(color: GlossColors.danger)),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: GlossSurfaces.logoAccent),
                ],
                const SizedBox(height: 20),
                _row('Job title', title, icon: Icons.work_outline),
                _row('Email', email, icon: Icons.mail_outline),
                _row('Phone', phone, icon: Icons.call_outlined),
                _row(
                  'Departments',
                  depts.isEmpty ? 'None assigned' : depts.join(' · '),
                  icon: Icons.apartment_outlined,
                ),
                if (hod.isNotEmpty)
                  _row(
                    'Head of department',
                    hod.join(' · '),
                    icon: Icons.star_outline,
                  ),
                const SizedBox(height: 12),
                if (phone != '—')
                  Align(
                    alignment: Alignment.center,
                    child: GlossSurfaces.glossCta(
                      label: 'CALL',
                      onTap: () => _call(m),
                    ),
                  ),
                if (isSelf) ...[
                  const SizedBox(height: 16),
                  Text(
                    'You can update name, phone, title, and photo. '
                    'Role and departments require an elevated role.',
                    style: GlossSurfaces.logoAccent.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (isOwner && !isSelf && m.role != OrgRoles.owner) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _transferOwnership(m),
                      child: Text(
                        'Transfer ownership',
                        style: GlossSurfaces.logoMark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You become System Admin. This cannot be undone from here.',
                    style: GlossSurfaces.logoAccent.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
