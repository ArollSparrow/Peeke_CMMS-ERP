import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'org_roles.dart';

export 'org_roles.dart' show OrgRoles, OrgDepartments;

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    this.testingUntil,
    this.reviewNote,
  });

  final String id;
  final String name;
  final String slug;
  final String status;
  final DateTime? testingUntil;
  final String? reviewNote;

  /// Hard gate: active always; testing while window open.
  bool get hasProductAccess {
    if (status == 'active') return true;
    if (status == 'testing') {
      if (testingUntil == null) return true;
      return testingUntil!.isAfter(DateTime.now().toUtc());
    }
    return false;
  }

  factory Organization.fromMap(Map<String, dynamic> m) {
    DateTime? until;
    final raw = m['testing_until'];
    if (raw is String) {
      until = DateTime.tryParse(raw)?.toUtc();
    } else if (raw is DateTime) {
      until = raw.toUtc();
    }
    return Organization(
      id: m['id'] as String,
      name: m['name'] as String,
      slug: m['slug'] as String,
      status: m['status'] as String? ?? 'pending',
      testingUntil: until,
      reviewNote: m['review_note'] as String?,
    );
  }
}

final myOrganizationsProvider =
    FutureProvider.autoDispose<List<Organization>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('organizations')
      .select('id, name, slug, status, testing_until, review_note');
  return (rows as List)
      .map((e) => Organization.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
});

final activeOrganizationIdProvider = StateProvider<String?>((ref) => null);

final activeOrganizationProvider = Provider<Organization?>((ref) {
  final id = ref.watch(activeOrganizationIdProvider);
  final orgs = ref.watch(myOrganizationsProvider).valueOrNull ?? [];
  if (id == null) return orgs.isEmpty ? null : orgs.first;
  try {
    return orgs.firstWhere((o) => o.id == id);
  } catch (_) {
    return orgs.isEmpty ? null : orgs.first;
  }
});

final activeMembershipRoleProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  final org = ref.watch(activeOrganizationProvider);
  if (user == null || org == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('organization_members')
      .select('role')
      .eq('organization_id', org.id)
      .eq('user_id', user.id)
      .maybeSingle();
  if (row == null) return null;
  return OrgRoles.normalize(row['role'] as String?);
});

class OrgCapabilities {
  const OrgCapabilities({
    required this.role,
    this.requireElevatedForApproval = false,
  });

  final String? role;
  final bool requireElevatedForApproval;

  bool get isElevated =>
      role != null && OrgRoles.elevated.contains(role);

  bool get isOwner => role == OrgRoles.owner;

  bool get isMember => role != null;

  bool get canApproveWork {
    if (!isMember) return false;
    if (!requireElevatedForApproval) return true;
    return isElevated ||
        role == OrgRoles.hod ||
        role == OrgRoles.supervisor;
  }

  bool get canOperate => isMember;
}

final orgCapabilitiesProvider = Provider.autoDispose<OrgCapabilities>((ref) {
  final role = ref.watch(activeMembershipRoleProvider).valueOrNull;
  return OrgCapabilities(
    role: role,
    requireElevatedForApproval: false,
  );
});

class OrgRepository {
  OrgRepository(this._client);

  final SupabaseClient _client;

  Future<Organization> createOrganization({
    required String name,
    required String slug,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to create an organization');
    }

    final row = await _client.rpc(
      'create_organization',
      params: {
        'p_name': name.trim(),
        'p_slug': slug.trim().toLowerCase(),
      },
    );

    if (row is! Map) {
      throw StateError('create_organization returned unexpected payload');
    }
    return Organization.fromMap(Map<String, dynamic>.from(row));
  }
}

final orgRepositoryProvider = Provider<OrgRepository>((ref) {
  return OrgRepository(ref.watch(supabaseClientProvider));
});
