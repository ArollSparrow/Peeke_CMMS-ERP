import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/gloss_theme.dart';
import '../../infra/friendly_error.dart';
import '../auth/auth_providers.dart';
import '../auth/login_screen.dart' show authRedirectTo;
import 'org_providers.dart';

class OrgMemberRow {
  const OrgMemberRow({
    required this.id,
    required this.userId,
    required this.role,
  });
  final String id;
  final String userId;
  final String role;
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
  final rows = await client
      .from('organization_members')
      .select('id, user_id, role')
      .eq('organization_id', org.id);
  return (rows as List)
      .map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return OrgMemberRow(
          id: m['id'] as String,
          userId: m['user_id'] as String,
          role: m['role'] as String? ?? 'member',
        );
      })
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
  return (rows as List)
      .map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return OrgInviteRow(
          id: m['id'] as String,
          email: m['email'] as String,
          role: m['role'] as String? ?? 'member',
          status: m['status'] as String? ?? 'pending',
        );
      })
      .toList();
});

class OrgTeamScreen extends ConsumerStatefulWidget {
  const OrgTeamScreen({super.key});

  @override
  ConsumerState<OrgTeamScreen> createState() => _OrgTeamScreenState();
}

class _OrgTeamScreenState extends ConsumerState<OrgTeamScreen> {
  final _email = TextEditingController();
  String _role = 'member';
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
          'redirect_to': authRedirectTo('/login'),
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
        final status = map['status']?.toString();
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
        const SnackBar(content: Text('Invite link copied — share via WhatsApp/SMS')),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          'Remove this ${member.role} from ${org.name}? '
          'They will lose access to org data immediately.',
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
      if (mounted) {
        setState(() => _message = 'Member removed');
      }
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
            'Invite by work email. Built-in Supabase email only reaches project team '
            'addresses — for others, copy the invite link and share it. '
            'They set a password, sign in, then become members.',
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
              items: const [
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'member'),
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
              Text(_error!, style: const TextStyle(color: GlossColors.navy)),
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
                'Only owners and admins can manage the team.',
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
                              ? 'You'
                              : (m.userId.length > 8
                                  ? '…${m.userId.substring(m.userId.length - 8)}'
                                  : m.userId),
                          style: const TextStyle(color: GlossColors.navy),
                        ),
                        subtitle: Text(m.role,
                            style: const TextStyle(color: GlossColors.teal)),
                        trailing: canInvite && m.userId != me
                            ? IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.person_remove_outlined),
                                color: GlossColors.navy,
                                onPressed: () => _removeMember(m),
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
                        subtitle: Text('${i.role} · ${i.status}'),
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
