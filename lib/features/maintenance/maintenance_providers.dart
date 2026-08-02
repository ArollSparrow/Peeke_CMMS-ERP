import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'maintenance_models.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._client);
  final SupabaseClient _client;

  // —— Technicians ——
  Future<List<Technician>> listTechnicians(String orgId, {bool activeOnly = true}) async {
    var q = _client.from('technicians').select().eq('organization_id', orgId);
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('name');
    return (rows as List)
        .map((e) => Technician.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Technician> createTechnician({
    required String organizationId,
    required String name,
    String? specialisation,
    String? contact,
    String? email,
    String? notes,
  }) async {
    final row = await _client
        .from('technicians')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          if (specialisation != null && specialisation.trim().isNotEmpty)
            'specialisation': specialisation.trim(),
          if (contact != null && contact.trim().isNotEmpty) 'contact': contact.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select()
        .single();
    return Technician.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Technician> updateTechnician(String id, Map<String, dynamic> patch) async {
    final row = await _client
        .from('technicians')
        .update({...patch, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Technician.fromMap(Map<String, dynamic>.from(row));
  }

  // —— PM Plans ——
  Future<List<PmPlan>> listPmPlans(String orgId) async {
    final results = await Future.wait([
      _client.from('pm_plans').select().eq('organization_id', orgId).order('next_due_at'),
      _client
          .from('work_orders')
          .select('pm_plan_id, status')
          .eq('organization_id', orgId)
          .not('pm_plan_id', 'is', null),
      _client
          .from('work_requests')
          .select('pm_plan_id, wr_number, status')
          .eq('organization_id', orgId)
          .not('pm_plan_id', 'is', null)
          .inFilter('status', ['pending', 'approved']),
    ]);

    const openStatuses = {
      'pending_supervisor',
      'pending_dept_head',
      'pending_warehouse',
      'pending_procurement',
      'parts_ordered',
      'ready_for_receipt',
      'parts_received',
      'parts_issued',
      'pending_dispatch',
      'in_progress',
      'pending_completion_approval',
      'open',
      'assigned',
    };

    final woCounts = <String, int>{};
    for (final w in results[1] as List) {
      final m = Map<String, dynamic>.from(w as Map);
      final pid = m['pm_plan_id'] as String?;
      final status = m['status'] as String? ?? '';
      if (pid != null && openStatuses.contains(status)) {
        woCounts[pid] = (woCounts[pid] ?? 0) + 1;
      }
    }

    final wrByPlan = <String, Map<String, dynamic>>{};
    for (final w in results[2] as List) {
      final m = Map<String, dynamic>.from(w as Map);
      final pid = m['pm_plan_id'] as String?;
      if (pid != null) wrByPlan.putIfAbsent(pid, () => m);
    }

    return (results[0] as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['id'] as String;
      m['open_wo_count'] = woCounts[id] ?? 0;
      final wr = wrByPlan[id];
      m['open_wr_number'] = wr?['wr_number'];
      m['open_wr_status'] = wr?['status'];
      return PmPlan.fromMap(m);
    }).toList();
  }

  Future<PmPlan?> getPmPlan(String id) async {
    final row = await _client.from('pm_plans').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return PmPlan.fromMap(Map<String, dynamic>.from(row));
  }

  Future<PmPlan> createPmPlan({
    required String organizationId,
    required String systemId,
    required String title,
    String? description,
    String triggerType = 'calendar',
    int intervalValue = 3,
    String intervalUnit = 'months',
    String priority = 'medium',
    bool autoGenerateWo = true,
    String generates = 'work_order',
    DateTime? startDate,
    int? meterIntervalHours,
  }) async {
    final row = await _client.rpc('create_pm_plan', params: {
      'p_org': organizationId,
      'p_system_id': systemId,
      'p_title': title,
      'p_description': description,
      'p_trigger_type': triggerType,
      'p_interval_value': intervalValue,
      'p_interval_unit': intervalUnit,
      'p_priority': priority,
      'p_auto_generate_wo': autoGenerateWo,
      'p_generates': generates,
      'p_start_date': (startDate ?? DateTime.now()).toUtc().toIso8601String(),
      'p_meter_interval_hours': meterIntervalHours,
    });
    return PmPlan.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<PmPlan> updatePmPlan(String id, Map<String, dynamic> patch) async {
    final row = await _client
        .from('pm_plans')
        .update({...patch, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return PmPlan.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deletePmPlan(String id) async {
    await _client.from('pm_plans').delete().eq('id', id);
  }

  Future<List<PmSopTemplate>> listSopTemplates() async {
    final rows = await _client
        .from('pm_sop_templates')
        .select()
        .eq('is_active', true)
        .order('system_category')
        .order('display_order');
    return (rows as List)
        .map((e) => PmSopTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> countDuePmPlans(String orgId) async {
    final n = await _client.rpc('count_due_pm_plans', params: {'p_org': orgId});
    return (n as num?)?.toInt() ?? 0;
  }

  // —— Maintenance records ——
  Future<List<MaintenanceRecord>> listRecords(String orgId, {String? systemId}) async {
    var q = _client.from('maintenance_records').select().eq('organization_id', orgId);
    if (systemId != null) q = q.eq('system_id', systemId);
    final rows = await q.order('performed_at', ascending: false).limit(100);
    return (rows as List)
        .map((e) => MaintenanceRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MaintenanceRecord> createRecord({
    required String organizationId,
    required String systemId,
    required String title,
    String? pmPlanId,
    String? technicianId,
    String jobType = 'corrective',
    String? findings,
    String? workDone,
    String? partsUsed,
    double? hourMeter,
    double downtimeHours = 0,
    String? performedBy,
    String? notes,
    String? systemType,
    String? systemSerial,
    String? clientName,
  }) async {
    final row = await _client
        .from('maintenance_records')
        .insert({
          'organization_id': organizationId,
          'system_id': systemId,
          'title': title.trim(),
          if (pmPlanId != null) 'pm_plan_id': pmPlanId,
          if (technicianId != null) 'technician_id': technicianId,
          'job_type': jobType,
          'status': 'completed',
          'performed_at': DateTime.now().toUtc().toIso8601String(),
          if (findings != null) 'findings': findings,
          if (workDone != null) 'work_done': workDone,
          if (partsUsed != null) 'parts_used': partsUsed,
          if (hourMeter != null) 'hour_meter': hourMeter,
          'downtime_hours': downtimeHours,
          if (performedBy != null) 'performed_by': performedBy,
          if (notes != null) 'notes': notes,
          if (systemType != null) 'system_type': systemType,
          if (systemSerial != null) 'system_serial': systemSerial,
          if (clientName != null) 'client_name': clientName,
        })
        .select()
        .single();
    return MaintenanceRecord.fromMap(Map<String, dynamic>.from(row));
  }
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(supabaseClientProvider));
});

final techniciansListProvider =
    FutureProvider.autoDispose<List<Technician>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(maintenanceRepositoryProvider).listTechnicians(org.id);
});

final pmPlansListProvider = FutureProvider.autoDispose<List<PmPlan>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(maintenanceRepositoryProvider).listPmPlans(org.id);
});

final pmPlanByIdProvider =
    FutureProvider.autoDispose.family<PmPlan?, String>((ref, id) {
  return ref.watch(maintenanceRepositoryProvider).getPmPlan(id);
});

final sopTemplatesProvider =
    FutureProvider.autoDispose<List<PmSopTemplate>>((ref) async {
  return ref.watch(maintenanceRepositoryProvider).listSopTemplates();
});

final duePmCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return 0;
  return ref.watch(maintenanceRepositoryProvider).countDuePmPlans(org.id);
});

final maintenanceRecordsProvider =
    FutureProvider.autoDispose<List<MaintenanceRecord>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(maintenanceRepositoryProvider).listRecords(org.id);
});
