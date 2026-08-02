class Client {
  const Client({
    required this.id,
    required this.organizationId,
    required this.name,
    this.code,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.address,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? code;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? notes;
  final bool isActive;

  factory Client.fromMap(Map<String, dynamic> m) {
    return Client(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      name: m['name'] as String,
      code: m['code'] as String?,
      contactName: m['contact_name'] as String?,
      contactEmail: m['contact_email'] as String?,
      contactPhone: m['contact_phone'] as String?,
      address: m['address'] as String?,
      notes: m['notes'] as String?,
      isActive: m['is_active'] as bool? ?? true,
    );
  }
}

class AssetSystem {
  const AssetSystem({
    required this.id,
    required this.organizationId,
    required this.name,
    this.clientId,
    this.code,
    this.systemType,
    this.model,
    this.serialNumber,
    this.siteName,
    this.status = 'active',
    this.notes,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? clientId;
  final String? code;
  final String? systemType;
  final String? model;
  final String? serialNumber;
  final String? siteName;
  final String status;
  final String? notes;

  factory AssetSystem.fromMap(Map<String, dynamic> m) {
    return AssetSystem(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      name: m['name'] as String,
      clientId: m['client_id'] as String?,
      code: m['code'] as String?,
      systemType: m['system_type'] as String?,
      model: m['model'] as String?,
      serialNumber: m['serial_number'] as String?,
      siteName: m['site_name'] as String?,
      status: m['status'] as String? ?? 'active',
      notes: m['notes'] as String?,
    );
  }
}
