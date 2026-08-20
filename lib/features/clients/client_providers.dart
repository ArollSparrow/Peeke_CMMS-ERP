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
        .select('*, clients(name, site_name, location)')
        .eq('organization_id', organizationId);

    final t = query?.trim();
    if (t != null && t.isNotEmpty) {
      filtered = filtered.or(
        'name.ilike.%$t%,code.ilike.%$t%,type.ilike.%$t%,model.ilike.%$t%',
      );
    }
    if (clientId != null && clientId.isNotEmpty) {
      filtered = filtered.eq('client_id', clientId);
    }

    final rows =
        await filtered.order('name').range(offset, offset + limit - 1);

    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final c = m.remove('clients');
      if (c is Map) {
        m['client_name'] = c['name'];
        m['client_site'] = c['site_name'];
        m['client_location'] = c['location'];
      }
      return AssetSystem.fromMap(m);
    }).toList();
  }

  Future<List<AssetSystem>> listByClient(String clientId) async {
    final rows = await _client
        .from('systems')
        .select('*, clients(name, site_name, location)')
        .eq('client_id', clientId)
        .order('name');
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final c = m.remove('clients');
      if (c is Map) {
        m['client_name'] = c['name'];
        m['client_site'] = c['site_name'];
        m['client_location'] = c['location'];
      }
      return AssetSystem.fromMap(m);
    }).toList();
  }

  Future<AssetSystem?> getById(String id) async {
    final row = await _client
        .from('systems')
        .select('*, clients(name, site_name, location)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    final c = m.remove('clients');
    if (c is Map) {
      m['client_name'] = c['name'];
      m['client_site'] = c['site_name'];
      m['client_location'] = c['location'];
    }
    return AssetSystem.fromMap(m);
  }

  Future<AssetSystem> create({
    required String organizationId,
    required String name,
    required String clientId,
    required String clientName,
    String? clientLocation,
    String? clientSite,
    String? code,
    String? type,
    String? model,
    String? serialNumber,
    double? capacity,
    String? capacityUnit,
    String? barcode,
    String? siteName,
    DateTime? installationDate,
    DateTime? registrationDate,
    double? fuelTankCapacity,
    double? initialHourMeter,
    double? initialEnergyMeter,
    String? operationType,
    String? status,
    String? notes,
  }) async {
    final row = await _client
        .from('systems')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          'client_id': clientId,
          'client_name': clientName,
          if (_trimOrNull(clientLocation) != null)
            'client_location': _trimOrNull(clientLocation),
          if (_trimOrNull(clientSite) != null)
            'client_site': _trimOrNull(clientSite),
          if (_trimOrNull(code) != null) 'code': _trimOrNull(code),
          if (_trimOrNull(type) != null) 'type': _trimOrNull(type),
          if (_trimOrNull(model) != null) 'model': _trimOrNull(model),
          if (_trimOrNull(serialNumber) != null)
            'serial_number': _trimOrNull(serialNumber),
          if (capacity != null) 'capacity': capacity,
          if (_trimOrNull(capacityUnit) != null)
            'capacity_unit': _trimOrNull(capacityUnit),
          if (_trimOrNull(barcode) != null) 'barcode': _trimOrNull(barcode),
          if (_trimOrNull(siteName) != null) 'site_name': _trimOrNull(siteName),
          if (installationDate != null)
            'installation_date': installationDate.toIso8601String(),
          if (registrationDate != null)
            'registration_date': registrationDate.toIso8601String(),
          if (fuelTankCapacity != null) 'fuel_tank_capacity': fuelTankCapacity,
          if (initialHourMeter != null) 'initial_hour_meter': initialHourMeter,
          if (initialEnergyMeter != null)
            'initial_energy_meter': initialEnergyMeter,
          if (_trimOrNull(operationType) != null)
            'operation_type': _trimOrNull(operationType),
          if (_trimOrNull(status) != null) 'status': _trimOrNull(status),
          if (_trimOrNull(notes) != null) 'notes': _trimOrNull(notes),
        })
        .select()
        .single();
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

  Future<void> delete(String id) async {
    await _client.from('systems').delete().eq('id', id);
  }
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(supabaseClientProvider));
});

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  return SystemRepository(ref.watch(supabaseClientProvider));
});

/// Reactive clients list.
///
/// - PowerSync configured → local SQLite watch (offline-first, live updates).
/// - Otherwise → one-shot Supabase fetch (online-only path).
/// Writes still go through [ClientRepository] → Postgres RLS.
final clientsListProvider =
    StreamProvider.autoDispose<List<Client>>((ref) async* {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) {
    yield const [];
    return;
  }

  if (PowerSyncEnv.isConfigured) {
    final db = await ref.watch(powerSyncDatabaseProvider.future);
    if (db != null) {
      yield* db
          .watch(
            'SELECT * FROM clients WHERE organization_id = ? ORDER BY name COLLATE NOCASE',
            parameters: [org.id],
          )
          .map(
            (rows) => rows
                .map((r) => Client.fromMap(Map<String, dynamic>.from(r)))
                .toList(growable: false),
          );
      return;
    }
  }

  yield await ref.watch(clientRepositoryProvider).list(organizationId: org.id);
});

/// Reactive systems list (same dual path as clients).
final systemsListProvider =
    StreamProvider.autoDispose<List<AssetSystem>>((ref) async* {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) {
    yield const [];
    return;
  }

  if (PowerSyncEnv.isConfigured) {
    final db = await ref.watch(powerSyncDatabaseProvider.future);
    if (db != null) {
      yield* db
          .watch(
            'SELECT * FROM systems WHERE organization_id = ? ORDER BY name COLLATE NOCASE',
            parameters: [org.id],
          )
          .map(
            (rows) => rows
                .map((r) => AssetSystem.fromMap(Map<String, dynamic>.from(r)))
                .toList(growable: false),
          );
      return;
    }
  }

  yield await ref.watch(systemRepositoryProvider).list(organizationId: org.id);
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
  if (PowerSyncEnv.isConfigured) {
    final db = await ref.watch(powerSyncDatabaseProvider.future);
    if (db != null) {
      final rows = await db.getAll(
        'SELECT * FROM systems WHERE id = ? LIMIT 1',
        [id],
      );
      if (rows.isNotEmpty) {
        return AssetSystem.fromMap(Map<String, dynamic>.from(rows.first));
      }
    }
  }
  return ref.watch(systemRepositoryProvider).getById(id);
});

final systemsByClientProvider =
    StreamProvider.autoDispose.family<List<AssetSystem>, String>((ref, clientId) async* {
  if (PowerSyncEnv.isConfigured) {
    final db = await ref.watch(powerSyncDatabaseProvider.future);
    if (db != null) {
      yield* db
          .watch(
            'SELECT * FROM systems WHERE client_id = ? ORDER BY name COLLATE NOCASE',
            parameters: [clientId],
          )
          .map(
            (rows) => rows
                .map((r) => AssetSystem.fromMap(Map<String, dynamic>.from(r)))
                .toList(growable: false),
          );
      return;
    }
  }
  yield await ref.watch(systemRepositoryProvider).listByClient(clientId);
});
