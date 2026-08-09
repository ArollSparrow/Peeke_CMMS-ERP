import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'maintenance_models.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._client);
  final SupabaseClient _client;

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
      'pending_approval',
      'awaiting_parts',
      'on_hold',
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

  Future<List<MaintenanceRecord>> listRecords(String orgId, {String? systemId}) async {
    var q = _client.from('maintenance_records').select().eq('organization_id', orgId);
    if (systemId != null) q = q.eq('system_id', systemId);
    final rows = await q.order('performed_at', ascending: false).limit(100);
    return (rows as List)
        .map((e) => MaintenanceRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MaintenanceRecord?> getRecordById(String id) async {
    final row =
        await _client.from('maintenance_records').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return MaintenanceRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<MaintenanceRecord?> getRecordByWorkOrderId(String workOrderId) async {
    final row = await _client
        .from('maintenance_records')
        .select()
        .eq('work_order_id', workOrderId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return MaintenanceRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<MaintenanceRecord> createRecord({
    required String organizationId,
    String? systemId,
    required String title,
    String? pmPlanId,
    String? workOrderId,
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
          if (systemId != null) 'system_id': systemId,
          'title': title.trim(),
          if (pmPlanId != null) 'pm_plan_id': pmPlanId,
          if (workOrderId != null) 'work_order_id': workOrderId,
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

  Future<MaintenanceRecord> updateRecord(String id, {
    String? findings,
    String? workDone,
    String? notes,
    String? partsUsed,
    double? hourMeter,
    double? downtimeHours,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (findings != null) patch['findings'] = findings.isEmpty ? null : findings;
    if (workDone != null) patch['work_done'] = workDone.isEmpty ? null : workDone;
    if (notes != null) patch['notes'] = notes.isEmpty ? null : notes;
    if (partsUsed != null) patch['parts_used'] = partsUsed.isEmpty ? null : partsUsed;
    if (hourMeter != null) patch['hour_meter'] = hourMeter;
    if (downtimeHours != null) patch['downtime_hours'] = downtimeHours;

    final row = await _client
        .from('maintenance_records')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return MaintenanceRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<DowntimeEvent>> listDowntimeEvents(
    String orgId, {
    String? systemId,
    String? workOrderId,
  }) async {
    var q = _client.from('downtime_events').select().eq('organization_id', orgId);
    if (systemId != null) q = q.eq('system_id', systemId);
    if (workOrderId != null) q = q.eq('work_order_id', workOrderId);
    final rows = await q.order('started_at', ascending: false).limit(200);
    return (rows as List)
        .map((e) => DowntimeEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listLinkedWork(String orgId, String planId) async {
    const openWo = {
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
      'pending_approval',
      'awaiting_parts',
      'on_hold',
    };
    final results = await Future.wait([
      _client
          .from('work_orders')
          .select('id, wo_number, status, created_at, description')
          .eq('organization_id', orgId)
          .eq('pm_plan_id', planId)
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('work_requests')
          .select('id, wr_number, status, created_at, description')
          .eq('organization_id', orgId)
          .eq('pm_plan_id', planId)
          .order('created_at', ascending: false)
          .limit(10),
    ]);

    final out = <Map<String, dynamic>>[];
    for (final w in results[0] as List) {
      final m = Map<String, dynamic>.from(w as Map);
      final status = m['status'] as String? ?? '';
      out.add({
        'kind': 'work_order',
        'id': m['id'],
        'number': m['wo_number'],
        'status': status,
        'created_at': m['created_at'],
        'description': m['description'],
        'is_open': openWo.contains(status),
      });
    }
    for (final w in results[1] as List) {
      final m = Map<String, dynamic>.from(w as Map);
      final status = m['status'] as String? ?? '';
      out.add({
        'kind': 'work_request',
        'id': m['id'],
        'number': m['wr_number'],
        'status': status,
        'created_at': m['created_at'],
        'description': m['description'],
        'is_open': status == 'pending' || status == 'approved',
      });
    }
    return out;
  }

  DateTime _advanceDue(DateTime from, int value, String unit) {
    final local = from.toLocal();
    switch (unit) {
      case 'days':
        return local.add(Duration(days: value));
      case 'weeks':
        return local.add(Duration(days: value * 7));
      case 'months':
        return DateTime(local.year, local.month + value, local.day, local.hour, local.minute);
      case 'hours':
        return local.add(Duration(hours: value));
      default:
        return local.add(Duration(days: value * 30));
    }
  }

  Future<void> _advancePlanAfterGenerate(PmPlan plan) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (!plan.isMeter) {
      final base = plan.nextDueAt ?? DateTime.now();
      final next = _advanceDue(base, plan.intervalValue, plan.intervalUnit);
      patch['next_due_at'] = next.toUtc().toIso8601String();
    }
    await _client.from('pm_plans').update(patch).eq('id', plan.id);
  }

  Future<Map<String, dynamic>> generateWorkFromPlan({
    required PmPlan plan,
    String? requestedBy,
    bool force = false,
  }) async {
    if (!force && (plan.openWoCount > 0 || plan.openWrNumber != null)) {
      throw StateError('OPEN_WORK_EXISTS');
    }

    final desc = plan.description?.trim().isNotEmpty == true
        ? plan.description!.trim()
        : plan.title;
    final notes = 'Generated from PM plan: ${plan.title}';

    if (plan.generates == 'work_request') {
      final number = await _client.rpc('next_wr_number', params: {'p_org': plan.organizationId});
      final row = await _client
          .from('work_requests')
          .insert({
            'organization_id': plan.organizationId,
            'wr_number': number as String,
            'description': desc,
            'system_id': plan.systemId,
            if (plan.clientName != null) 'client_name': plan.clientName,
            if (plan.clientSite != null) 'client_site': plan.clientSite,
            if (plan.systemType != null) 'system_type': plan.systemType,
            if (plan.systemSerial != null) 'system_serial': plan.systemSerial,
            'job_type': 'scheduled',
            'priority': plan.priority,
            if (requestedBy != null) 'requested_by': requestedBy,
            'notes': notes,
            'pm_plan_id': plan.id,
            'status': 'pending',
          })
          .select()
          .single();
      await _advancePlanAfterGenerate(plan);
      return {
        'kind': 'work_request',
        'id': row['id'],
        'number': row['wr_number'],
      };
    }

    final number = await _client.rpc('next_wo_number', params: {'p_org': plan.organizationId});
    final row = await _client
        .from('work_orders')
        .insert({
          'organization_id': plan.organizationId,
          'wo_number': number as String,
          'description': desc,
          'system_id': plan.systemId,
          if (plan.clientName != null) 'client_name': plan.clientName,
          if (plan.clientSite != null) 'client_site': plan.clientSite,
          if (plan.systemType != null) 'system_type': plan.systemType,
          if (plan.systemSerial != null) 'system_serial': plan.systemSerial,
          'job_type': 'scheduled',
          'priority': plan.priority,
          if (requestedBy != null) 'requested_by': requestedBy,
          'notes': notes,
          'pm_plan_id': plan.id,
          'status': 'open',
        })
        .select()
        .single();

    await _client.from('work_order_events').insert({
      'organization_id': plan.organizationId,
      'work_order_id': row['id'],
      'action': 'generated_from_pm',
      'stage': 'creation',
      'to_status': 'open',
      'actor': requestedBy,
      'notes': notes,
    });

    await _advancePlanAfterGenerate(plan);
    return {
      'kind': 'work_order',
      'id': row['id'],
      'number': row['wo_number'],
    };
  }

  Future<PmPlan> recordMeterReading({
    required String planId,
    required double reading,
  }) async {
    final plan = await getPmPlan(planId);
    if (plan == null) throw Exception('Plan not found');
    final patch = <String, dynamic>{
      'last_meter_reading': reading,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final interval = plan.meterIntervalHours ?? plan.intervalValue;
    if (plan.isMeter && interval > 0) {
      patch['next_due_meter'] = reading + interval;
    }
    final row = await _client
        .from('pm_plans')
        .update(patch)
        .eq('id', planId)
        .select()
        .single();
    return PmPlan.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> logDowntime({
    required String organizationId,
    String? systemId,
    String? workOrderId,
    String? maintenanceRecordId,
    required double hours,
    String? reason,
    String? category,
    String? loggedBy,
    String? systemType,
    String? systemSerial,
    String? clientName,
    String? notes,
  }) async {
    if (hours <= 0) return;
    final ended = DateTime.now().toUtc();
    final started = ended.subtract(Duration(minutes: (hours * 60).round()));
    await _client.from('downtime_events').insert({
      'organization_id': organizationId,
      if (systemId != null) 'system_id': systemId,
      if (workOrderId != null) 'work_order_id': workOrderId,
      if (maintenanceRecordId != null)
        'maintenance_record_id': maintenanceRecordId,
      'started_at': started.toIso8601String(),
      'ended_at': ended.toIso8601String(),
      if (reason != null) 'reason': reason,
      'category': category ?? 'maintenance',
      if (loggedBy != null) 'logged_by': loggedBy,
      if (systemType != null) 'system_type': systemType,
      if (systemSerial != null) 'system_serial': systemSerial,
      if (clientName != null) 'client_name': clientName,
      if (notes != null) 'notes': notes,
    });
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

final maintenanceRecordByIdProvider =
    FutureProvider.autoDispose.family<MaintenanceRecord?, String>((ref, id) {
  return ref.watch(maintenanceRepositoryProvider).getRecordById(id);
});

final downtimeEventsProvider =
    FutureProvider.autoDispose<List<DowntimeEvent>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(maintenanceRepositoryProvider).listDowntimeEvents(org.id);
});

final pmPlanLinkedWorkProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, planId) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(maintenanceRepositoryProvider).listLinkedWork(org.id, planId);
});

/// M5 — system-scoped slices for asset reliability surface.
final maintenanceRecordsBySystemProvider = FutureProvider.autoDispose
    .family<List<MaintenanceRecord>, String>((ref, systemId) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref
      .watch(maintenanceRepositoryProvider)
      .listRecords(org.id, systemId: systemId);
});

final downtimeEventsBySystemProvider = FutureProvider.autoDispose
    .family<List<DowntimeEvent>, String>((ref, systemId) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref
      .watch(maintenanceRepositoryProvider)
      .listDowntimeEvents(org.id, systemId: systemId);
});

final pmPlansBySystemProvider =
    FutureProvider.autoDispose.family<List<PmPlan>, String>((ref, systemId) async {
  final all = await ref.watch(pmPlansListProvider.future);
  return all.where((p) => p.systemId == systemId).toList();
});
