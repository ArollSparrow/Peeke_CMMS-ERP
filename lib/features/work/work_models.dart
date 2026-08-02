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

class WorkJobTypes {
  static const values = ['breakdown', 'corrective', 'inspection', 'scheduled'];
}

class WorkPriorities {
  static const values = ['low', 'medium', 'high', 'critical'];
}
