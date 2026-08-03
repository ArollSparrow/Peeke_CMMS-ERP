class OperationRecord {
  const OperationRecord({
    required this.id,
    required this.organizationId,
    required this.systemId,
    required this.opKey,
    this.opMode = 'single',
    this.recordedAt,
    this.attendant,
    this.status,
    this.hourMeter,
    this.powerMeter,
    this.waterMeter,
    this.fuelAdded,
    this.fuelCapacity,
    this.consumption,
    this.faultCode,
    this.cause,
    this.resolution,
    this.notes,
    this.systemType,
    this.systemSerial,
    this.clientName,
    this.clientSite,
    this.performedBy,
  });

  final String id;
  final String organizationId;
  final String systemId;
  final String opKey;
  final String opMode;
  final DateTime? recordedAt;
  final String? attendant;
  final String? status;
  final double? hourMeter;
  final double? powerMeter;
  final double? waterMeter;
  final double? fuelAdded;
  final double? fuelCapacity;
  final double? consumption;
  final String? faultCode;
  final String? cause;
  final String? resolution;
  final String? notes;
  final String? systemType;
  final String? systemSerial;
  final String? clientName;
  final String? clientSite;
  final String? performedBy;

  factory OperationRecord.fromMap(Map<String, dynamic> m) => OperationRecord(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        systemId: m['system_id'] as String,
        opKey: m['op_key'] as String,
        opMode: m['op_mode'] as String? ?? 'single',
        recordedAt: m['recorded_at'] != null
            ? DateTime.tryParse(m['recorded_at'].toString())
            : null,
        attendant: m['attendant'] as String?,
        status: m['status'] as String?,
        hourMeter: (m['hour_meter'] as num?)?.toDouble(),
        powerMeter: (m['power_meter'] as num?)?.toDouble(),
        waterMeter: (m['water_meter'] as num?)?.toDouble(),
        fuelAdded: (m['fuel_added'] as num?)?.toDouble(),
        fuelCapacity: (m['fuel_capacity'] as num?)?.toDouble(),
        consumption: (m['consumption'] as num?)?.toDouble(),
        faultCode: m['fault_code'] as String?,
        cause: m['cause'] as String?,
        resolution: m['resolution'] as String?,
        notes: m['notes'] as String?,
        systemType: m['system_type'] as String?,
        systemSerial: m['system_serial'] as String?,
        clientName: m['client_name'] as String?,
        clientSite: m['client_site'] as String?,
        performedBy: m['performed_by'] as String?,
      );

  String get opLabel {
    switch (opKey) {
      case 'gen_pump':
        return 'Generator · Pumping';
      case 'gen_utility':
        return 'Generator · Utility';
      case 'solar_pump':
        return 'Solar · Pumping';
      case 'pv_utility':
        return 'PV · Utility';
      case 'gen_fueling':
        return 'Fueling';
      case 'breakdown_report':
        return 'Breakdown';
      default:
        return opKey;
    }
  }

  String get subtitle {
    final parts = <String>[
      opMode,
      if (systemType != null && systemType!.isNotEmpty) systemType!,
      if (clientName != null && clientName!.isNotEmpty) clientName!,
      if (hourMeter != null) 'HM ${hourMeter!.toStringAsFixed(1)}',
    ];
    return parts.join(' · ');
  }
}

class OpTypeDef {
  const OpTypeDef({
    required this.key,
    required this.name,
    required this.modes,
    required this.icon,
  });
  final String key;
  final String name;
  final List<String> modes;
  final String icon;
}

class OperationCatalog {
  static const types = [
    OpTypeDef(key: 'gen_pump', name: 'Generator · Pumping', modes: ['start', 'stop'], icon: 'settings'),
    OpTypeDef(key: 'gen_utility', name: 'Generator · Utility', modes: ['start', 'stop'], icon: 'bolt'),
    OpTypeDef(key: 'solar_pump', name: 'Solar · Pumping', modes: ['start', 'stop'], icon: 'wb_sunny'),
    OpTypeDef(key: 'pv_utility', name: 'PV · Utility', modes: ['single'], icon: 'solar_power'),
    OpTypeDef(key: 'gen_fueling', name: 'Generator · Fueling', modes: ['single'], icon: 'local_gas_station'),
    OpTypeDef(key: 'breakdown_report', name: 'Breakdown', modes: ['report', 'resolved'], icon: 'warning'),
  ];

  static List<OpTypeDef> forSystemType(String? systemType) {
    if (systemType == null) return types;
    final t = systemType.toLowerCase();
    if (t.contains('generator')) {
      return types
          .where((o) => o.key == 'gen_pump' || o.key == 'gen_utility' || o.key == 'gen_fueling')
          .toList();
    }
    if (t.contains('pump')) {
      return types.where((o) => o.key == 'solar_pump').toList();
    }
    if (t.contains('pv') || t.contains('solar') || t.contains('inverter')) {
      return types.where((o) => o.key == 'pv_utility').toList();
    }
    return types;
  }
}
