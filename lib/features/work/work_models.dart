class WorkRequest {
  const WorkRequest({
    required this.id,
    required this.organizationId,
    this.wrNumber,
    this.clientId,
    this.systemId,
    this.clientName,
    this.clientSite,
    this.systemType,
    this.systemModel,
    this.systemSerial,
    this.jobType = 'corrective',
    this.priority = 'medium',
    this.requestedBy,
    this.description,
    this.faultDescription,
    this.notes,
    this.status = 'pending',
    this.needsProcurement = false,
    this.reviewedBy,
    this.reviewNotes,
    this.reviewedAt,
    this.workOrderId,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String? wrNumber;
  final String? clientId;
  final String? systemId;
  final String? clientName;
  final String? clientSite;
  final String? systemType;
  final String? systemModel;
  final String? systemSerial;
  final String jobType;
  final String priority;
  final String? requestedBy;
  final String? description;
  final String? faultDescription;
  final String? notes;
  final String status;
  final bool needsProcurement;
  final String? reviewedBy;
  final String? reviewNotes;
  final DateTime? reviewedAt;
  final String? workOrderId;
  final DateTime? createdAt;

  factory WorkRequest.fromMap(Map<String, dynamic> m) {
    return WorkRequest(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      wrNumber: m['wr_number'] as String?,
      clientId: m['client_id'] as String?,
      systemId: m['system_id'] as String?,
      clientName: m['client_name'] as String?,
      clientSite: m['client_site'] as String?,
      systemType: m['system_type'] as String?,
      systemModel: m['system_model'] as String?,
      systemSerial: m['system_serial'] as String?,
      jobType: m['job_type'] as String? ?? 'corrective',
      priority: m['priority'] as String? ?? 'medium',
      requestedBy: m['requested_by'] as String?,
      description: m['description'] as String?,
      faultDescription: m['fault_description'] as String?,
      notes: m['notes'] as String?,
      status: m['status'] as String? ?? 'pending',
      needsProcurement: m['needs_procurement'] as bool? ?? false,
      reviewedBy: m['reviewed_by'] as String?,
      reviewNotes: m['review_notes'] as String?,
      reviewedAt: m['reviewed_at'] != null
          ? DateTime.tryParse(m['reviewed_at'].toString())
          : null,
      workOrderId: m['work_order_id'] as String?,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())
          : null,
    );
  }

  String get subtitle {
    final parts = <String>[
      if (clientName != null) clientName!,
      if (systemType != null) systemType!,
      priority,
    ];
    return parts.join(' · ');
  }
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.organizationId,
    this.woNumber,
    this.workRequestId,
    this.clientId,
    this.systemId,
    this.clientName,
    this.clientSite,
    this.systemType,
    this.systemModel,
    this.systemSerial,
    this.jobType = 'corrective',
    this.priority = 'medium',
    this.requestedBy,
    this.description,
    this.faultDescription,
    this.notes,
    this.status = 'open',
    this.needsProcurement = false,
    this.assignedTechnician,
    this.completedBy,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String? woNumber;
  final String? workRequestId;
  final String? clientId;
  final String? systemId;
  final String? clientName;
  final String? clientSite;
  final String? systemType;
  final String? systemModel;
  final String? systemSerial;
  final String jobType;
  final String priority;
  final String? requestedBy;
  final String? description;
  final String? faultDescription;
  final String? notes;
  final String status;
  final bool needsProcurement;
  final String? assignedTechnician;
  final String? completedBy;
  final DateTime? completedAt;
  final DateTime? createdAt;

  factory WorkOrder.fromMap(Map<String, dynamic> m) {
    return WorkOrder(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      woNumber: m['wo_number'] as String?,
      workRequestId: m['work_request_id'] as String?,
      clientId: m['client_id'] as String?,
      systemId: m['system_id'] as String?,
      clientName: m['client_name'] as String?,
      clientSite: m['client_site'] as String?,
      systemType: m['system_type'] as String?,
      systemModel: m['system_model'] as String?,
      systemSerial: m['system_serial'] as String?,
      jobType: m['job_type'] as String? ?? 'corrective',
      priority: m['priority'] as String? ?? 'medium',
      requestedBy: m['requested_by'] as String?,
      description: m['description'] as String?,
      faultDescription: m['fault_description'] as String?,
      notes: m['notes'] as String?,
      status: m['status'] as String? ?? 'open',
      needsProcurement: m['needs_procurement'] as bool? ?? false,
      assignedTechnician: m['assigned_technician'] as String?,
      completedBy: m['completed_by'] as String?,
      completedAt: m['completed_at'] != null
          ? DateTime.tryParse(m['completed_at'].toString())
          : null,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())
          : null,
    );
  }

  String get subtitle {
    final parts = <String>[
      if (clientName != null) clientName!,
      if (systemType != null) systemType!,
      status,
    ];
    return parts.join(' · ');
  }

  bool get isOpen =>
      status == 'open' || status == 'in_progress' || status == 'on_hold';
}

class WorkOrderPart {
  const WorkOrderPart({
    required this.id,
    required this.organizationId,
    required this.workOrderId,
    required this.partName,
    this.sparePartId,
    this.partNumber,
    this.source = 'internal',
    this.qtyRequired = 1,
    this.unitCost = 0,
    this.procurementStatus = 'pending',
    this.purchaseOrderId,
    this.notes,
  });

  final String id;
  final String organizationId;
  final String workOrderId;
  final String? sparePartId;
  final String partName;
  final String? partNumber;
  final String source;
  final double qtyRequired;
  final double unitCost;
  final String procurementStatus;
  final String? purchaseOrderId;
  final String? notes;

  factory WorkOrderPart.fromMap(Map<String, dynamic> m) {
    return WorkOrderPart(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      workOrderId: m['work_order_id'] as String,
      sparePartId: m['spare_part_id'] as String?,
      partName: m['part_name'] as String? ?? 'Part',
      partNumber: m['part_number'] as String?,
      source: m['source'] as String? ?? 'internal',
      qtyRequired: (m['qty_required'] as num?)?.toDouble() ?? 1,
      unitCost: (m['unit_cost'] as num?)?.toDouble() ?? 0,
      procurementStatus: m['procurement_status'] as String? ?? 'pending',
      purchaseOrderId: m['purchase_order_id'] as String?,
      notes: m['notes'] as String?,
    );
  }

  bool get isExternal => source == 'external';

  /// Internal + linked to catalogue + still pending → can deduct stock.
  bool get canIssueFromStock =>
      source == 'internal' &&
      procurementStatus == 'pending' &&
      sparePartId != null;

  /// External + pending + not yet linked to any PO → eligible for Raise PO.
  /// Prevents duplicate draft POs for the same lines.
  bool get canRaisePo =>
      source == 'external' &&
      procurementStatus == 'pending' &&
      purchaseOrderId == null;

  /// Soft-linked to a draft (or later) PO but still pending status.
  bool get hasLinkedPo => purchaseOrderId != null;
}

class WorkOrderEvent {
  const WorkOrderEvent({
    required this.id,
    required this.workOrderId,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.stage,
    this.actor,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String workOrderId;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? stage;
  final String? actor;
  final String? notes;
  final DateTime? createdAt;

  factory WorkOrderEvent.fromMap(Map<String, dynamic> m) {
    return WorkOrderEvent(
      id: m['id'] as String,
      workOrderId: m['work_order_id'] as String,
      action: m['action'] as String? ?? 'event',
      fromStatus: m['from_status'] as String?,
      toStatus: m['to_status'] as String?,
      stage: m['stage'] as String?,
      actor: m['actor'] as String?,
      notes: m['notes'] as String?,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())
          : null,
    );
  }

  String get title {
    if (action == 'issued' || action == 'received' || action == 'parts_ordered') {
      return _label(action);
    }
    if (toStatus != null) return _label(toStatus!);
    if (stage != null) return _label(stage!);
    return action;
  }

  static String _label(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class WorkJobTypes {
  static const values = ['breakdown', 'corrective', 'inspection', 'scheduled'];
}

class WorkPriorities {
  static const values = ['low', 'medium', 'high', 'critical'];
}

class WorkOrderStatuses {
  static const filterChips = [
    null,
    'open',
    'in_progress',
    'on_hold',
    'completed',
    'cancelled',
  ];

  static String label(String? s) {
    if (s == null) return 'All';
    return s
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class WorkRequestStatuses {
  static const filterChips = [
    null,
    'pending',
    'approved',
    'converted',
    'rejected',
  ];

  static String label(String? s) {
    if (s == null) return 'All';
    return s
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
