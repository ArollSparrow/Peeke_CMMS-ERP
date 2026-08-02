class Client {
  const Client({
    required this.id,
    required this.organizationId,
    required this.name,
    this.code,
    this.siteName,
    this.location,
    this.contact,
    this.locationCoords,
    this.phone,
    this.email,
    this.billingAddress,
    this.accountManager,
    this.accountType,
    this.slaHours,
    this.isActive = true,
    this.notes,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? code;
  final String? siteName;
  final String? location;
  final String? contact;
  final String? locationCoords;
  final String? phone;
  final String? email;
  final String? billingAddress;
  final String? accountManager;
  final String? accountType;
  final int? slaHours;
  final bool isActive;
  final String? notes;

  factory Client.fromMap(Map<String, dynamic> m) {
    return Client(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      name: m['name'] as String,
      code: m['code'] as String?,
      siteName: m['site_name'] as String?,
      location: m['location'] as String?,
      contact: m['contact'] as String? ?? m['contact_name'] as String?,
      locationCoords: m['location_coords'] as String?,
      phone: m['phone'] as String? ?? m['contact_phone'] as String?,
      email: m['email'] as String? ?? m['contact_email'] as String?,
      billingAddress: m['billing_address'] as String? ?? m['address'] as String?,
      accountManager: m['account_manager'] as String?,
      accountType: m['account_type'] as String?,
      slaHours: m['sla_hours'] as int?,
      isActive: m['is_active'] as bool? ?? true,
      notes: m['notes'] as String?,
    );
  }

  String get subtitle {
    final parts = <String>[
      if (siteName != null && siteName!.isNotEmpty) siteName!,
      if (location != null && location!.isNotEmpty) location!,
      if (phone != null && phone!.isNotEmpty) phone!,
    ];
    return parts.join(' · ');
  }

  String get displaySite =>
      [name, if (siteName != null && siteName!.isNotEmpty) siteName!]
          .join(' · ');
}

class AssetSystem {
  const AssetSystem({
    required this.id,
    required this.organizationId,
    required this.name,
    this.clientId,
    this.clientName,
    this.clientLocation,
    this.clientSite,
    this.code,
    this.type,
    this.model,
    this.serialNumber,
    this.capacity,
    this.capacityUnit,
    this.barcode,
    this.siteName,
    this.status = 'active',
    this.notes,
    this.installationDate,
    this.registrationDate,
    this.fuelTankCapacity,
    this.initialHourMeter,
    this.initialEnergyMeter,
    this.operationType,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? clientId;
  final String? clientName;
  final String? clientLocation;
  final String? clientSite;
  final String? code;
  final String? type;
  final String? model;
  final String? serialNumber;
  final double? capacity;
  final String? capacityUnit;
  final String? barcode;
  final String? siteName;
  final String status;
  final String? notes;
  final DateTime? installationDate;
  final DateTime? registrationDate;
  final double? fuelTankCapacity;
  final double? initialHourMeter;
  final double? initialEnergyMeter;
  final String? operationType;

  factory AssetSystem.fromMap(Map<String, dynamic> m) {
    double? numOrNull(dynamic v) => v is num ? v.toDouble() : null;
    DateTime? dateOrNull(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return AssetSystem(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      name: m['name'] as String,
      clientId: m['client_id'] as String?,
      clientName: m['client_name'] as String?,
      clientLocation: m['client_location'] as String?,
      clientSite: m['client_site'] as String?,
      code: m['code'] as String?,
      type: m['type'] as String? ?? m['system_type'] as String?,
      model: m['model'] as String?,
      serialNumber: m['serial_number'] as String?,
      capacity: numOrNull(m['capacity']),
      capacityUnit: m['capacity_unit'] as String?,
      barcode: m['barcode'] as String?,
      siteName: m['site_name'] as String?,
      status: m['status'] as String? ?? 'active',
      notes: m['notes'] as String?,
      installationDate: dateOrNull(m['installation_date']),
      registrationDate: dateOrNull(m['registration_date']),
      fuelTankCapacity: numOrNull(m['fuel_tank_capacity']),
      initialHourMeter: numOrNull(m['initial_hour_meter']),
      initialEnergyMeter: numOrNull(m['initial_energy_meter']),
      operationType: m['operation_type'] as String?,
    );
  }

  String get capacityLabel {
    if (capacity == null) return '';
    final v = capacity! % 1 == 0
        ? capacity!.toStringAsFixed(0)
        : capacity!.toStringAsFixed(1);
    return '$v${capacityUnit ?? ''}';
  }

  String get subtitle {
    final parts = <String>[
      if (clientName != null && clientName!.isNotEmpty) clientName!,
      if (type != null && type!.isNotEmpty) type!,
      if (serialNumber != null && serialNumber!.isNotEmpty) serialNumber!,
      if (capacityLabel.isNotEmpty) capacityLabel,
    ];
    return parts.join(' · ');
  }

  String get systemLabel {
    if (model != null && model!.isNotEmpty && type != null) {
      return '$type — $model';
    }
    return type ?? name;
  }
}
