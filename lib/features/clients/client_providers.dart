import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'client_models.dart';

const _pageSize = 30;

class ClientRepository {
  ClientRepository(this._client);
  final SupabaseClient _client;

  Future<List<Client>> list({
    required String organizationId,
    int offset = 0,
    int limit = _pageSize,
    String? query,
  }) async {
    var q = _client
        .from('clients')
        .select()
        .eq('organization_id', organizationId)
        .order('name')
        .range(offset, offset + limit - 1);

    if (query != null && query.trim().isNotEmpty) {
      final t = query.trim();
      q = q.or('name.ilike.%$t%,code.ilike.%$t%');
    }

    final rows = await q;
    return (rows as List)
        .map((e) => Client.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Client> create({
    required String organizationId,
    required String name,
    String? code,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
  }) async {
    final row = await _client
        .from('clients')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          if (contactName != null && contactName.trim().isNotEmpty)
            'contact_name': contactName.trim(),
          if (contactEmail != null && contactEmail.trim().isNotEmpty)
            'contact_email': contactEmail.trim(),
          if (contactPhone != null && contactPhone.trim().isNotEmpty)
            'contact_phone': contactPhone.trim(),
        })
        .select()
        .single();
    return Client.fromMap(Map<String, dynamic>.from(row));
  }
}

class SystemRepository {
  SystemRepository(this._client);
  final SupabaseClient _client;

  Future<List<AssetSystem>> list({
    required String organizationId,
    int offset = 0,
    int limit = _pageSize,
    String? query,
  }) async {
    var q = _client
        .from('systems')
        .select()
        .eq('organization_id', organizationId)
        .order('name')
        .range(offset, offset + limit - 1);

    if (query != null && query.trim().isNotEmpty) {
      final t = query.trim();
      q = q.or('name.ilike.%$t%,code.ilike.%$t%,serial_number.ilike.%$t%');
    }

    final rows = await q;
    return (rows as List)
        .map((e) => AssetSystem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AssetSystem> create({
    required String organizationId,
    required String name,
    String? clientId,
    String? code,
    String? systemType,
    String? model,
    String? serialNumber,
    String? siteName,
  }) async {
    final row = await _client
        .from('systems')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          if (clientId != null) 'client_id': clientId,
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          if (systemType != null && systemType.trim().isNotEmpty)
            'system_type': systemType.trim(),
          if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
          if (serialNumber != null && serialNumber.trim().isNotEmpty)
            'serial_number': serialNumber.trim(),
          if (siteName != null && siteName.trim().isNotEmpty)
            'site_name': siteName.trim(),
        })
        .select()
        .single();
    return AssetSystem.fromMap(Map<String, dynamic>.from(row));
  }
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(supabaseClientProvider));
});

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  return SystemRepository(ref.watch(supabaseClientProvider));
});

/// First page of clients for the active org.
final clientsListProvider =
    FutureProvider.autoDispose<List<Client>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(clientRepositoryProvider).list(organizationId: org.id);
});

final systemsListProvider =
    FutureProvider.autoDispose<List<AssetSystem>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(systemRepositoryProvider).list(organizationId: org.id);
});
