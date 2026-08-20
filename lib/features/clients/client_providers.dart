import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../infra/sync/powersync_env.dart';
import '../../infra/sync/sync_providers.dart';
import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'client_models.dart';

const _pageSize = 50;

String? _trimOrNull(String? v) {
  final t = v?.trim();
  if (t == null || t.isEmpty) return null;
  return t;
}

class ClientRepository {
  ClientRepository(this._client);
  final SupabaseClient _client;

  Future<List<Client>> list({
    required String organizationId,
    int offset = 0,
    int limit = _pageSize,
    String? query,
  }) async {
    var filtered = _client
        .from('clients')
        .select()
        .eq('organization_id', organizationId);

    final t = query?.trim();
    if (t != null && t.isNotEmpty) {
      filtered = filtered.or(
        'name.ilike.%$t%,site_name.ilike.%$t%,location.ilike.%$t%,code.ilike.%$t%,phone.ilike.%$t%',
      );
    }

    final rows =
        await filtered.order('name').range(offset, offset + limit - 1);

    return (rows as List)
        .map((e) => Client.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Client?> getById(String id) async {
    final row =
        await _client.from('clients').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Client.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Client> create({
    required String organizationId,
    required String name,
    String? code,
    String? siteName,
    String? location,
    String? contact,
    String? locationCoords,
    String? phone,
    String? email,
    String? billingAddress,
    String? accountManager,
    String? accountType,
    int? slaHours,
    String? notes,
  }) async {
    final row = await _client
        .from('clients')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          if (_trimOrNull(code) != null) 'code': _trimOrNull(code),
          if (_trimOrNull(siteName) != null) 'site_name': _trimOrNull(siteName),
          if (_trimOrNull(location) != null) 'location': _trimOrNull(location),
          if (_trimOrNull(contact) != null) 'contact': _trimOrNull(contact),
          if (_trimOrNull(locationCoords) != null)
            'location_coords': _trimOrNull(locationCoords),
          if (_trimOrNull(phone) != null) 'phone': _trimOrNull(phone),
          if (_trimOrNull(email) != null) 'email': _trimOrNull(email),
          if (_trimOrNull(billingAddress) != null)
            'billing_address': _trimOrNull(billingAddress),
          if (_trimOrNull(accountManager) != null)
            'account_manager': _trimOrNull(accountManager),
          if (accountType != null) 'account_type': accountType,
          if (slaHours != null) 'sla_hours': slaHours,
          if (_trimOrNull(notes) != null) 'notes': _trimOrNull(notes),
        })
        .select()
        .single();
    return Client.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Client> update(String id, Map<String, dynamic> patch) async {
    final row = await _client
        .from('clients')
        .update({
          ...patch,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
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
    String? clientId,
  }) async {
    var filtered = _client
        .from('systems')
        .select('*, clients(name, location, site_name)')
        .eq('organization_id', organizationId);

    if (clientId != null) {
      filtered = filtered.eq('client_id', clientId);
    }

    final t = query?.trim();
    if (t != null && t.isNotEmpty) {
      filtered = filtered.or(
        'name.ilike.%$t%,code.ilike.%$t%,type.ilike.%$t%,site_name.ilike.%$t%',
      );
    }

    final rows =
        await filtered.order('name').range(offset, offset + limit - 1);

    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final c = m['clients'];
      if (c is Map) {
        m['client_name'] = c['name'];
        m['client_location'] = c['location'];
        m['client_site'] = c['site_name'];
      }
      return AssetSystem.fromMap(m);
    }).toList();
  }

  Future<List<AssetSystem>> listByClient(String clientId) async {
    final rows = await _client
        .from('systems')
        .select('*, clients(name, location, site_name)')
        .eq('client_id', clientId)
        .order('name');
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final c = m['clients'];
      if (c is Map) {
        m['client_name'] = c['name'];
        m['client_location'] = c['location'];
        m['client_site'] = c['site_name'];
      }
      return AssetSystem.fromMap(m);
    }).toList();
  }

  Future<AssetSystem?> getById(String id) async {
    final row = await _client
        .from('systems')
        .select('*, clients(name, location, site_name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    final c = m['clients'];
    if (c is Map) {
      m['client_name'] = c['name'];
      m['client_location'] = c['location'];
      m['client_site'] = c['site_name'];
    }
    return AssetSystem.fromMap(m);
  }

  Future<AssetSystem> create(Map<String, dynamic> data) async {
    final row =
        await _client.from('systems').insert(data).select().single();
    return AssetSystem.fromMap(Map<String, dynamic>.from(row));
  }

  Future<AssetSystem> update(String id, Map<String, dynamic> patch) async {
    final row = await _client
        .from('systems')
        .update({
          ...patch,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
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

/// Prefer local SQLite when PowerSync is configured and the DB is open;
/// otherwise fall back to live Supabase (online-only path).
/// Writes still go through [ClientRepository] → Postgres RLS.
final clientsListProvider =
    FutureProvider.autoDispose<List<Client>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];

  if (PowerSyncEnv.isConfigured) {
    final db = await ref.watch(powerSyncDatabaseProvider.future);
    if (db != null) {
      final rows = await db.getAll(
        'SELECT * FROM clients WHERE organization_id = ? ORDER BY name COLLATE NOCASE',
        [org.id],
      );
      // Empty local cache before first sync: fall through to network.
      if (rows.isNotEmpty) {
        return rows
            .map((r) => Client.fromMap(Map<String, dynamic>.from(r)))
            .toList();
      }
    }
  }

  return ref.watch(clientRepositoryProvider).list(organizationId: org.id);
});

final systemsListProvider =
    FutureProvider.autoDispose<List<AssetSystem>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(systemRepositoryProvider).list(organizationId: org.id);
});

final clientByIdProvider =
    FutureProvider.autoDispose.family<Client?, String>((ref, id) async {
  if (PowerSyncEnv.isConfigured) {
    final db = await ref.watch(powerSyncDatabaseProvider.future);
    if (db != null) {
      final rows = await db.getAll(
        'SELECT * FROM clients WHERE id = ? LIMIT 1',
        [id],
      );
      if (rows.isNotEmpty) {
        return Client.fromMap(Map<String, dynamic>.from(rows.first));
      }
    }
  }
  return ref.watch(clientRepositoryProvider).getById(id);
});

final systemByIdProvider =
    FutureProvider.autoDispose.family<AssetSystem?, String>((ref, id) async {
  return ref.watch(systemRepositoryProvider).getById(id);
});

final systemsByClientProvider =
    FutureProvider.autoDispose.family<List<AssetSystem>, String>((ref, clientId) async {
  return ref.watch(systemRepositoryProvider).listByClient(clientId);
});
