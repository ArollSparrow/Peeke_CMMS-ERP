import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
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
    this.isActive = true,
    this.sortOrder = 0,
  });
  final String id;
  final String code;
  final String name;
  final bool isActive;
  final int sortOrder;
}

final orgDepartmentsProvider =
    FutureProvider.autoDispose<List<OrgDept>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  final client = ref.watch(supabaseClientProvider);

  Future<List<OrgDept>> load() async {
    final rows = await client
        .from('organization_departments')
        .select('id, code, name, sort_order, is_active')
        .eq('organization_id', org.id)
        .order('sort_order');
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OrgDept(
        id: m['id'] as String,
        code: m['code'] as String,
        name: m['name'] as String? ?? OrgDepartments.label(m['code'] as String),
        isActive: m['is_active'] as bool? ?? true,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
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

/// Active departments only — member assignment picker.
final orgActiveDepartmentsProvider =
    Provider.autoDispose<AsyncValue<List<OrgDept>>>((ref) {
  return ref.watch(orgDepartmentsProvider).whenData(
        (list) => list.where((d) => d.isActive).toList(),
      );
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
