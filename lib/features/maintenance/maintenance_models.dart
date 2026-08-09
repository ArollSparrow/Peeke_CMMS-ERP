class Technician {
  const Technician({
    required this.id,
    required this.organizationId,
    required this.name,
    this.specialisation,
    this.contact,
    this.email,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? specialisation;
  final String? contact;
  final String? email;
  final String? notes;
  final bool isActive;

  factory Technician.fromMap(Map<String, dynamic> m) => Technician(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        name: m['name'] as String,
        specialisation: m['specialisation'] as String?,
        contact: m['contact'] as String?,
        email: m['email'] as String?,
        notes: m['notes'] as String?,
        isActive: m['is_active'] as bool? ?? true,
      );

  String get subtitle {
    final parts = <String>[
      if (specialisation != null && specialisation!.isNotEmpty) specialisation!,
      if (contact != null && contact!.isNotEmpty) contact!,
    ];
    return parts.isEmpty ? 'Technician' : parts.join(' · ');
  }
}

class PmPlan {
  const PmPlan({
    required this.id,
    required this.organizationId,
    required this.systemId,
    required this.title,
    this.description,
    this.triggerType = 'calendar',
    this.intervalValue = 3,
    this.intervalUnit = 'months',
    this.meterIntervalHours,
    this.priority = 'medium',
    this.autoGenerateWo = true,
    this.generates = 'work_order',
    this.isActive = true,
    this.nextDueAt,
    this.nextDueMeter,
    this.lastMeterReading,
    this.lastCompletedAt,
    this.systemType,
    this.systemSerial,
    this.clientName,
    this.clientSite,
    this.openWoCount = 0,
    this.openWrNumber,
    this.openWrStatus,
  });

  final String id;
  final String organizationId;
  final String systemId;
  final String title;
  final String? description;
  final String triggerType;
  final int intervalValue;
  final String intervalUnit;
  final int? meterIntervalHours;
  final String priority;
  final bool autoGenerateWo;
  final String generates;
  final bool isActive;
  final DateTime? nextDueAt;
  final double? nextDueMeter;
  final double? lastMeterReading;
  final DateTime? lastCompletedAt;
  final String? systemType;
  final String? systemSerial;
  final String? clientName;
  final String? clientSite;
  final int openWoCount;
  final String? openWrNumber;
  final String? openWrStatus;

  factory PmPlan.fromMap(Map<String, dynamic> m) => PmPlan(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        systemId: m['system_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        triggerType: m['trigger_type'] as String? ?? 'calendar',
        intervalValue: (m['interval_value'] as num?)?.toInt() ?? 3,
        intervalUnit: m['interval_unit'] as String? ?? 'months',
        meterIntervalHours: (m['meter_interval_hours'] as num?)?.toInt(),
        priority: m['priority'] as String? ?? 'medium',
        autoGenerateWo: m['auto_generate_wo'] as bool? ?? true,
        generates: m['generates'] as String? ?? 'work_order',
        isActive: m['is_active'] as bool? ?? true,
        nextDueAt: m['next_due_at'] != null
            ? DateTime.tryParse(m['next_due_at'].toString())
            : null,
        nextDueMeter: (m['next_due_meter'] as num?)?.toDouble(),
        lastMeterReading: (m['last_meter_reading'] as num?)?.toDouble(),
        lastCompletedAt: m['last_completed_at'] != null
            ? DateTime.tryParse(m['last_completed_at'].toString())
            : null,
        systemType: m['system_type'] as String?,
        systemSerial: m['system_serial'] as String?,
        clientName: m['client_name'] as String?,
        clientSite: m['client_site'] as String?,
        openWoCount: (m['open_wo_count'] as num?)?.toInt() ?? 0,
        openWrNumber: m['open_wr_number'] as String?,
        openWrStatus: m['open_wr_status'] as String?,
      );

  bool get isMeter => triggerType == 'meter';

  String get intervalLabel {
    if (isMeter) {
      final h = meterIntervalHours ?? intervalValue;
      return 'Every $h hrs';
    }
    return 'Every $intervalValue $intervalUnit';
  }

  /// overdue | due | upcoming | inactive | in_progress
  String get planStatus {
    if (!isActive) return 'inactive';
    if (openWoCount > 0 || openWrNumber != null) return 'in_progress';
    if (isMeter) return 'upcoming';
    if (nextDueAt == null) return 'due';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = nextDueAt!.toLocal();
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;
    if (diff < 0) return 'overdue';
    if (diff <= 7) return 'due';
    return 'upcoming';
  }

  String get systemLine {
    final parts = <String>[
      if (systemType != null && systemType!.isNotEmpty) systemType!,
      if (systemSerial != null && systemSerial!.isNotEmpty) systemSerial!,
      if (clientName != null && clientName!.isNotEmpty) clientName!,
    ];
    return parts.join(' · ');
  }
}

class PmSopTemplate {
  const PmSopTemplate({
    required this.id,
    required this.name,
    this.description,
    this.systemCategory = 'all',
    this.triggerType = 'calendar',
    this.intervalValue,
    this.intervalUnit,
    this.meterIntervalHours,
    this.priority = 'medium',
  });

  final String id;
  final String name;
  final String? description;
  final String systemCategory;
  final String triggerType;
  final int? intervalValue;
  final String? intervalUnit;
  final int? meterIntervalHours;
  final String priority;

  factory PmSopTemplate.fromMap(Map<String, dynamic> m) => PmSopTemplate(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        systemCategory: m['system_category'] as String? ?? 'all',
        triggerType: m['trigger_type'] as String? ?? 'calendar',
        intervalValue: (m['interval_value'] as num?)?.toInt(),
        intervalUnit: m['interval_unit'] as String?,
        meterIntervalHours: (m['meter_interval_hours'] as num?)?.toInt(),
        priority: m['priority'] as String? ?? 'medium',
      );
}

class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.organizationId,
    this.systemId,
    required this.title,
    this.pmPlanId,
    this.workOrderId,
    this.technicianId,
    this.jobType = 'corrective',
    this.status = 'completed',
    this.performedAt,
    this.hourMeter,
    this.findings,
    this.workDone,
    this.partsUsed,
    this.downtimeHours = 0,
    this.performedBy,
    this.notes,
    this.systemType,
    this.systemSerial,
    this.clientName,
  });

  final String id;
  final String organizationId;
  /// Nullable: WO-originated job cards may not have a linked system row yet.
  final String? systemId;
  final String title;
  final String? pmPlanId;
  final String? workOrderId;
  final String? technicianId;
  final String jobType;
  final String status;
  final DateTime? performedAt;
  final double? hourMeter;
  final String? findings;
  final String? workDone;
  final String? partsUsed;
  final double downtimeHours;
  final String? performedBy;
  final String? notes;
  final String? systemType;
  final String? systemSerial;
  final String? clientName;

  factory MaintenanceRecord.fromMap(Map<String, dynamic> m) => MaintenanceRecord(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        systemId: m['system_id'] as String?,
        title: m['title'] as String,
        pmPlanId: m['pm_plan_id'] as String?,
        workOrderId: m['work_order_id'] as String?,
        technicianId: m['technician_id'] as String?,
        jobType: m['job_type'] as String? ?? 'corrective',
        status: m['status'] as String? ?? 'completed',
        performedAt: m['performed_at'] != null
            ? DateTime.tryParse(m['performed_at'].toString())
            : null,
        hourMeter: (m['hour_meter'] as num?)?.toDouble(),
        findings: m['findings'] as String?,
        workDone: m['work_done'] as String?,
        partsUsed: m['parts_used'] as String?,
        downtimeHours: (m['downtime_hours'] as num?)?.toDouble() ?? 0,
        performedBy: m['performed_by'] as String?,
        notes: m['notes'] as String?,
        systemType: m['system_type'] as String?,
        systemSerial: m['system_serial'] as String?,
        clientName: m['client_name'] as String?,
      );
}
