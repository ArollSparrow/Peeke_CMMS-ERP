import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
  });

  final String id;
  final String name;
  final String slug;
  final String status;

  factory Organization.fromMap(Map<String, dynamic> m) {
    return Organization(
      id: m['id'] as String,
      name: m['name'] as String,
      slug: m['slug'] as String,
      status: m['status'] as String? ?? 'active',
    );
  }
}

/// Known membership roles (organization_members.role).
/// Matches DB values used by is_org_admin(): owner | admin | member.
class OrgRoles {
  static const owner = 'owner';
  static const admin = 'admin';
  static const member = 'member';

  static const elevated = {owner, admin};
}

/// Orgs the signed-in user belongs to (RLS-filtered).
final myOrganizationsProvider =
    FutureProvider.autoDispose<List<Organization>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final rows = await client.from('organizations').select();
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

/// Current user's role in the active organization (null if signed out / no org).
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
  return row['role'] as String? ?? OrgRoles.member;
});

/// Capability flags for the active membership.
///
/// **Policy today (E2E-friendly):** any org member can approve / reject WOs and WRs.
/// **Future:** flip [OrgCapabilities.requireElevatedForApproval] to true and
/// wire UI/RPC to [canApproveWork] so only owner/admin pass.
class OrgCapabilities {
  const OrgCapabilities({
    required this.role,
    this.requireElevatedForApproval = false,
  });

  final String? role;

  /// When true, only owner/admin may approve or reject work.
  /// Keep false until multi-user tenants need gated queues.
  final bool requireElevatedForApproval;

  bool get isElevated =>
      role != null && OrgRoles.elevated.contains(role);

  bool get isMember => role != null;

  /// WR/WO approval & reject. Unrestricted while requireElevatedForApproval is false.
  bool get canApproveWork {
    if (!isMember) return false;
    if (!requireElevatedForApproval) return true;
    return isElevated;
  }

  /// Create org-scoped records, raise POs, issue stock, status changes.
  bool get canOperate => isMember;
}

final orgCapabilitiesProvider = Provider.autoDispose<OrgCapabilities>((ref) {
  final role = ref.watch(activeMembershipRoleProvider).valueOrNull;
  return OrgCapabilities(
    role: role,
    // Foundation only — do not enforce elevated approval yet.
    requireElevatedForApproval: false,
  );
});

class OrgRepository {
  OrgRepository(this._client);

  final SupabaseClient _client;

  /// Creates org + owner membership in one SECURITY DEFINER RPC.
  /// Avoids INSERT...RETURNING RLS failure before membership exists.
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
