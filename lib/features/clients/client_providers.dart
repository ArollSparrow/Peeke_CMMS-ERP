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
    var filtered = _client
        .from('clients')
        .select()
        .eq('organization_id', organizationId);

    final t = query?.trim();
    if (t != null && t.isNotEmpty) {
      filtered = filtered.or(
        'name.ilike.%$t%,site_name.ilike.%$t%,location.ilike.%$t%,code.ilike.%$t%',
      );
    }

    final rows =
        await filtered.order('name').range(offset, offset + limit - 1);

    return (rows as List)
        .map((e) => Client.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Client> create({
    required String organizationId,
    required String name,
    String? code,
    String? siteName,
    String? location,
    String? contact,
    String? phone,
    String? email,
    String? billingAddress,
    String? accountManager,
    String? accountType,
    int? slaHours,
  }) async {
    final row = await _client
        .from('clients')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          if (siteName != null && siteName.trim().isNotEmpty)
            'site_name': siteName.trim(),
          if (location != null && location.trim().isNotEmpty)
            'location': location.trim(),
          if (contact != null && contact.trim().isNotEmpty)
            'contact': contact.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (billingAddress != null && billingAddress.trim().isNotEmpty)
            'billing_address': billingAddress.trim(),
          if (accountManager != null && accountManager.trim().isNotEmpty)
            'account_manager': accountManager.trim(),
          if (accountType != null) 'account_type': accountType,
          if (slaHours != null) 'sla_hours': slaHours,
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
    String? clientId,
  }) async {
    var filtered = _client
        .from('systems')
        .select()
        .eq('organization_id', organizationId);

    if (clientId != null) {
      filtered = filtered.eq('client_id', clientId);
    }

    final t = query?.trim();
    if (t != null && t.isNotEmpty) {
      filtered = filtered.or(
        'name.ilike.%$t%,code.ilike.%$t%,serial_number.ilike.%$t%,client_name.ilike.%$t%,type.ilike.%$t%',
      );
    }

    final rows =
        await filtered.order('name').range(offset, offset + limit - 1);

    return (rows as List)
        .map((e) => AssetSystem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Creates a system linked to a client (production pattern).
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
  }) async {
    final row = await _client
        .from('systems')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          'client_id': clientId,
          'client_name': clientName,
          if (clientLocation != null) 'client_location': clientLocation,
          if (clientSite != null) 'client_site': clientSite,
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          if (type != null && type.trim().isNotEmpty) ...{
            'type': type.trim(),
            'system_type': type.trim(),
          },
          if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
          if (serialNumber != null && serialNumber.trim().isNotEmpty)
            'serial_number': serialNumber.trim(),
          if (capacity != null) 'capacity': capacity,
          if (capacityUnit != null) 'capacity_unit': capacityUnit,
          if (barcode != null && barcode.trim().isNotEmpty)
            'barcode': barcode.trim(),
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
