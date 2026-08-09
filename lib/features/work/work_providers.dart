import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'work_models.dart';

class WorkRepository {
  WorkRepository(this._client);
  final SupabaseClient _client;

  Future<List<WorkRequest>> listRequests({
    required String organizationId,
    String? status,
  }) async {
    var q = _client
        .from('work_requests')
        .select()
        .eq('organization_id', organizationId);
    if (status != null && status.isNotEmpty) {
      q = q.eq('status', status);
    }
    final rows = await q.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((e) => WorkRequest.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<WorkOrder>> listOrders({
    required String organizationId,
    String? status,
  }) async {
    var q = _client
        .from('work_orders')
        .select()
        .eq('organization_id', organizationId);
    if (status != null && status.isNotEmpty) {
      q = q.eq('status', status);
    }
    final rows = await q.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<WorkRequest?> getRequest(String id) async {
    final row =
        await _client.from('work_requests').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return WorkRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<WorkOrder?> getOrder(String id) async {
    final row =
        await _client.from('work_orders').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return WorkOrder.fromMap(Map<String, dynamic>.from(row));
  }

  Future<String> _nextWrNumber(String orgId) async {
    final n = await _client.rpc('next_wr_number', params: {'p_org': orgId});
    return n as String;
  }

  Future<String> _nextWoNumber(String orgId) async {
    final n = await _client.rpc('next_wo_number', params: {'p_org': orgId});
    return n as String;
  }

  Future<WorkRequest> createRequest({
    required String organizationId,
    required String description,
    String? clientId,
    String? systemId,
    String? clientName,
    String? clientSite,
    String? systemType,
    String? systemModel,
    String? systemSerial,
    String jobType = 'corrective',
    String priority = 'medium',
    String? requestedBy,
    String? faultDescription,
    String? notes,
    bool needsProcurement = false,
  }) async {
    final number = await _nextWrNumber(organizationId);
    final row = await _client
        .from('work_requests')
        .insert({
          'organization_id': organizationId,
          'wr_number': number,
          'description': description.trim(),
          if (clientId != null) 'client_id': clientId,
          if (systemId != null) 'system_id': systemId,
          if (clientName != null) 'client_name': clientName,
          if (clientSite != null) 'client_site': clientSite,
          if (systemType != null) 'system_type': systemType,
          if (systemModel != null) 'system_model': systemModel,
          if (systemSerial != null) 'system_serial': systemSerial,
          'job_type': jobType,
          'priority': priority,
          if (requestedBy != null) 'requested_by': requestedBy,
          if (faultDescription != null) 'fault_description': faultDescription,
          if (notes != null) 'notes': notes,
          'needs_procurement': needsProcurement,
          'status': 'pending',
        })
        .select()
        .single();
    return WorkRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<WorkRequest> updateRequestStatus(
    String id, {
    required String status,
    String? reviewedBy,
    String? reviewNotes,
    String? workOrderId,
  }) async {
    final row = await _client
        .from('work_requests')
        .update({
          'status': status,
          if (reviewedBy != null) 'reviewed_by': reviewedBy,
          if (reviewNotes != null) 'review_notes': reviewNotes,
          if (status == 'approved' ||
              status == 'rejected' ||
              status == 'converted')
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          if (workOrderId != null) 'work_order_id': workOrderId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return WorkRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<WorkOrder> createOrder({
    required String organizationId,
    required String description,
    String? workRequestId,
    String? clientId,
    String? systemId,
    String? clientName,
    String? clientSite,
    String? systemType,
    String? systemModel,
    String? systemSerial,
    String jobType = 'corrective',
    String priority = 'medium',
    String? requestedBy,
    String? faultDescription,
    String? notes,
    String? assignedTechnician,
    bool needsProcurement = false,
  }) async {
    final number = await _nextWoNumber(organizationId);
    final row = await _client
        .from('work_orders')
        .insert({
          'organization_id': organizationId,
          'wo_number': number,
          'description': description.trim(),
          if (workRequestId != null) 'work_request_id': workRequestId,
          if (clientId != null) 'client_id': clientId,
          if (systemId != null) 'system_id': systemId,
          if (clientName != null) 'client_name': clientName,
          if (clientSite != null) 'client_site': clientSite,
          if (systemType != null) 'system_type': systemType,
          if (systemModel != null) 'system_model': systemModel,
          if (systemSerial != null) 'system_serial': systemSerial,
          'job_type': jobType,
          'priority': priority,
          if (requestedBy != null) 'requested_by': requestedBy,
          if (faultDescription != null) 'fault_description': faultDescription,
          if (notes != null) 'notes': notes,
          if (assignedTechnician != null)
            'assigned_technician': assignedTechnician,
          'needs_procurement': needsProcurement,
          'status': 'open',
        })
        .select()
        .single();
    return WorkOrder.fromMap(Map<String, dynamic>.from(row));
  }

  Future<WorkOrder> convertRequestToOrder(
    WorkRequest wr, {
    String? reviewedBy,
    String? assignedTechnician,
  }) async {
    final wo = await createOrder(
      organizationId: wr.organizationId,
      description: wr.description ?? '',
      workRequestId: wr.id,
      clientId: wr.clientId,
      systemId: wr.systemId,
      clientName: wr.clientName,
      clientSite: wr.clientSite,
      systemType: wr.systemType,
      systemModel: wr.systemModel,
      systemSerial: wr.systemSerial,
      jobType: wr.jobType,
      priority: wr.priority,
      requestedBy: wr.requestedBy,
      faultDescription: wr.faultDescription,
      notes: wr.notes,
      assignedTechnician: assignedTechnician,
      needsProcurement: wr.needsProcurement,
    );
    await updateRequestStatus(
      wr.id,
      status: 'converted',
      reviewedBy: reviewedBy,
      workOrderId: wo.id,
    );
    return wo;
  }

  Future<WorkOrder> updateOrderStatus(
    String id, {
    required String status,
    String? completedBy,
    String? notes,
    String? assignedTechnician,
  }) async {
    final row = await _client
        .from('work_orders')
        .update({
          'status': status,
          if (assignedTechnician != null)
            'assigned_technician': assignedTechnician,
          if (status == 'completed') ...{
            'completed_by': completedBy,
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          },
          if (status == 'cancelled') ...{
            'cancelled_by': completedBy,
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            if (notes != null) 'cancel_notes': notes,
          },
          if (notes != null && status != 'cancelled') 'notes': notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return WorkOrder.fromMap(Map<String, dynamic>.from(row));
  }

  Future<WorkOrder> assignTechnician(String id, String technicianName) async {
    final row = await _client
        .from('work_orders')
        .update({
          'assigned_technician': technicianName,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    // Explicit event (status may be unchanged)
    final m = Map<String, dynamic>.from(row);
    await _client.from('work_order_events').insert({
      'organization_id': m['organization_id'],
      'work_order_id': id,
      'action': 'assigned',
      'stage': 'assignment',
      'to_status': m['status'],
      'actor': technicianName,
      'notes': 'Assigned technician',
    });
    return WorkOrder.fromMap(m);
  }

  Future<List<WorkOrderPart>> listParts(String workOrderId) async {
    final rows = await _client
        .from('work_order_parts')
        .select()
        .eq('work_order_id', workOrderId)
        .order('created_at');
    return (rows as List)
        .map((e) => WorkOrderPart.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<WorkOrderPart> addPart({
    required String organizationId,
    required String workOrderId,
    required String partName,
    String? sparePartId,
    String? partNumber,
    String source = 'internal',
    double qtyRequired = 1,
    double unitCost = 0,
    String? notes,
  }) async {
    final row = await _client
        .from('work_order_parts')
        .insert({
          'organization_id': organizationId,
          'work_order_id': workOrderId,
          'part_name': partName.trim(),
          if (sparePartId != null) 'spare_part_id': sparePartId,
          if (partNumber != null) 'part_number': partNumber,
          'source': source,
          'qty_required': qtyRequired,
          'unit_cost': unitCost,
          if (notes != null) 'notes': notes,
        })
        .select()
        .single();
    return WorkOrderPart.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deletePart(String partId) async {
    await _client.from('work_order_parts').delete().eq('id', partId);
  }

  Future<List<WorkOrderEvent>> listEvents(String workOrderId) async {
    final rows = await _client
        .from('work_order_events')
        .select()
        .eq('work_order_id', workOrderId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => WorkOrderEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> countOpenOrders(String organizationId) async {
    final rows = await _client
        .from('work_orders')
        .select('id')
        .eq('organization_id', organizationId)
        .inFilter('status', ['open', 'in_progress', 'on_hold']);
    return (rows as List).length;
  }

  Future<int> countPendingRequests(String organizationId) async {
    final rows = await _client
        .from('work_requests')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('status', 'pending');
    return (rows as List).length;
  }
}

final workRepositoryProvider = Provider<WorkRepository>((ref) {
  return WorkRepository(ref.watch(supabaseClientProvider));
});

/// Status filter for WR list (`null` = all).
final workRequestStatusFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Status filter for WO list (`null` = all).
final workOrderStatusFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final workRequestsListProvider =
    FutureProvider.autoDispose<List<WorkRequest>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  final status = ref.watch(workRequestStatusFilterProvider);
  return ref.watch(workRepositoryProvider).listRequests(
        organizationId: org.id,
        status: status,
      );
});

final workOrdersListProvider =
    FutureProvider.autoDispose<List<WorkOrder>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  final status = ref.watch(workOrderStatusFilterProvider);
  return ref.watch(workRepositoryProvider).listOrders(
        organizationId: org.id,
        status: status,
      );
});

final workRequestByIdProvider =
    FutureProvider.autoDispose.family<WorkRequest?, String>((ref, id) {
  return ref.watch(workRepositoryProvider).getRequest(id);
});

final workOrderByIdProvider =
    FutureProvider.autoDispose.family<WorkOrder?, String>((ref, id) {
  return ref.watch(workRepositoryProvider).getOrder(id);
});

final workOrderPartsProvider =
    FutureProvider.autoDispose.family<List<WorkOrderPart>, String>((ref, woId) {
  return ref.watch(workRepositoryProvider).listParts(woId);
});

final workOrderEventsProvider =
    FutureProvider.autoDispose.family<List<WorkOrderEvent>, String>((ref, woId) {
  return ref.watch(workRepositoryProvider).listEvents(woId);
});

final openWorkOrdersCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return 0;
  return ref.watch(workRepositoryProvider).countOpenOrders(org.id);
});

final pendingWorkRequestsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return 0;
  return ref.watch(workRepositoryProvider).countPendingRequests(org.id);
});
