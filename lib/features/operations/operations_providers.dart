import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'operations_models.dart';

class OperationsRepository {
  OperationsRepository(this._client);
  final SupabaseClient _client;

  Future<List<OperationRecord>> listRecords(String orgId, {String? systemId, int limit = 100}) async {
    var q = _client.from('operation_records').select().eq('organization_id', orgId);
    if (systemId != null) q = q.eq('system_id', systemId);
    final rows = await q.order('recorded_at', ascending: false).limit(limit);
    return (rows as List)
        .map((e) => OperationRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OperationRecord> createRecord({
    required String organizationId,
    required String systemId,
    required String opKey,
    required String opMode,
    String? attendant,
    String? status,
    double? hourMeter,
    double? powerMeter,
    double? waterMeter,
    double? fuelAdded,
    double? fuelCapacity,
    String? faultCode,
    String? cause,
    String? resolution,
    String? notes,
    String? systemType,
    String? systemSerial,
    String? clientName,
    String? clientSite,
    String? performedBy,
    DateTime? recordedAt,
  }) async {
    final row = await _client
        .from('operation_records')
        .insert({
          'organization_id': organizationId,
          'system_id': systemId,
          'op_key': opKey,
          'op_mode': opMode,
          'recorded_at': (recordedAt ?? DateTime.now()).toUtc().toIso8601String(),
          if (attendant != null && attendant.trim().isNotEmpty) 'attendant': attendant.trim(),
          if (status != null) 'status': status,
          if (hourMeter != null) 'hour_meter': hourMeter,
          if (powerMeter != null) 'power_meter': powerMeter,
          if (waterMeter != null) 'water_meter': waterMeter,
          if (fuelAdded != null) 'fuel_added': fuelAdded,
          if (fuelCapacity != null) 'fuel_capacity': fuelCapacity,
          if (faultCode != null) 'fault_code': faultCode,
          if (cause != null) 'cause': cause,
          if (resolution != null) 'resolution': resolution,
          if (notes != null) 'notes': notes,
          if (systemType != null) 'system_type': systemType,
          if (systemSerial != null) 'system_serial': systemSerial,
          if (clientName != null) 'client_name': clientName,
          if (clientSite != null) 'client_site': clientSite,
          if (performedBy != null) 'performed_by': performedBy,
        })
        .select()
        .single();
    return OperationRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<double?> latestHourMeter(String orgId, String systemId) async {
    final n = await _client.rpc('latest_system_hour_meter', params: {
      'p_org': orgId,
      'p_system_id': systemId,
    });
    return (n as num?)?.toDouble();
  }

  Future<int> countOpsToday(String orgId) async {
    final n = await _client.rpc('count_ops_today', params: {'p_org': orgId});
    return (n as num?)?.toInt() ?? 0;
  }
}

final operationsRepositoryProvider = Provider<OperationsRepository>((ref) {
  return OperationsRepository(ref.watch(supabaseClientProvider));
});

final operationRecordsProvider =
    FutureProvider.autoDispose<List<OperationRecord>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(operationsRepositoryProvider).listRecords(org.id);
});

final opsTodayCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return 0;
  return ref.watch(operationsRepositoryProvider).countOpsToday(org.id);
});
