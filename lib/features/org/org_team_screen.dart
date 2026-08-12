import 'package:flutter/material.dart';
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
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke(
        'invite-org-member',
        body: {
          'organization_id': org.id,
          'email': email,
          'role': _role,
          'redirect_to': authRedirectTo('/gate'),
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
      } else if (map['error'] != null && map['status'] == null) {
        setState(() => _error = map!['error'].toString());
      } else {
        final status = map['status']?.toString();
        final msg = map['message']?.toString();
        if (status == 'email_sent') {
          setState(() => _message = msg ??
              'Invite email sent to $email. Ask them to check inbox and spam.');
        } else if (status == 'added') {
          setState(() => _message =
              msg ?? 'They already had an account and were added to the org.');
        } else if (status == 'invite_failed') {
          setState(() => _message =
              'Invite saved for $email, but email may not have sent. '
              'Ask them to Register with this exact email, then Sign in.');
        } else {
          setState(() => _message = msg ?? 'Invite saved for $email.');
        }
        _email.clear();
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(orgMembersProvider);
    final invites = ref.watch(orgInvitesProvider);
    final caps = ref.watch(orgCapabilitiesProvider);
    final canInvite = caps.isElevated;

    return Scaffold(
      backgroundColor: GlossColors.sky,
      appBar: AppBar(title: const Text('Team')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Invite by work email. New people get a Supabase invite email '
            '(check spam). Existing accounts are added immediately.',
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
            const SizedBox(height: 24),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Only owners and admins can invite members.',
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
                          m.userId.length > 8
                              ? '…${m.userId.substring(m.userId.length - 8)}'
                              : m.userId,
                          style: const TextStyle(color: GlossColors.navy),
                        ),
                        subtitle: Text(m.role,
                            style: const TextStyle(color: GlossColors.teal)),
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
