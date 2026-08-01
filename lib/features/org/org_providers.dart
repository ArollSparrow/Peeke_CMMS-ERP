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

class OrgRepository {
  OrgRepository(this._client);

  final SupabaseClient _client;

  /// Creates org and membership as owner in one client flow.
  Future<Organization> createOrganization({
    required String name,
    required String slug,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to create an organization');
    }

    final inserted = await _client
        .from('organizations')
        .insert({'name': name, 'slug': slug})
        .select()
        .single();

    final org = Organization.fromMap(Map<String, dynamic>.from(inserted));

    await _client.from('organization_members').insert({
      'organization_id': org.id,
      'user_id': user.id,
      'role': 'owner',
    });

    return org;
  }
}

final orgRepositoryProvider = Provider<OrgRepository>((ref) {
  return OrgRepository(ref.watch(supabaseClientProvider));
});
