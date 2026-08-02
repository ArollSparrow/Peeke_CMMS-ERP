class SparePart {
  const SparePart({
    required this.id,
    required this.organizationId,
    required this.name,
    this.partNumber,
    this.description,
    this.category,
    this.unit = 'pcs',
    this.quantityOnHand = 0,
    this.reorderLevel = 0,
    this.unitCost = 0,
    this.location,
    this.supplierName,
    this.isActive = true,
    this.notes,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? partNumber;
  final String? description;
  final String? category;
  final String unit;
  final double quantityOnHand;
  final double reorderLevel;
  final double unitCost;
  final String? location;
  final String? supplierName;
  final bool isActive;
  final String? notes;

  factory SparePart.fromMap(Map<String, dynamic> m) {
    double num(dynamic v) => v is num ? v.toDouble() : 0;
    return SparePart(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      name: m['name'] as String,
      partNumber: m['part_number'] as String?,
      description: m['description'] as String?,
      category: m['category'] as String?,
      unit: m['unit'] as String? ?? 'pcs',
      quantityOnHand: num(m['quantity_on_hand']),
      reorderLevel: num(m['reorder_level']),
      unitCost: num(m['unit_cost']),
      location: m['location'] as String?,
      supplierName: m['supplier_name'] as String?,
      isActive: m['is_active'] as bool? ?? true,
      notes: m['notes'] as String?,
    );
  }

  bool get isLowStock => quantityOnHand <= reorderLevel;

  String get subtitle {
    final parts = <String>[
      if (partNumber != null && partNumber!.isNotEmpty) partNumber!,
      if (category != null && category!.isNotEmpty) category!,
      '${_fmtQty(quantityOnHand)} $unit',
    ];
    return parts.join(' · ');
  }

  static String _fmtQty(double q) =>
      q % 1 == 0 ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.organizationId,
    required this.sparePartId,
    required this.txnType,
    required this.quantity,
    this.unitCost,
    this.reference,
    this.workOrderId,
    this.notes,
    this.performedBy,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String sparePartId;
  final String txnType;
  final double quantity;
  final double? unitCost;
  final String? reference;
  final String? workOrderId;
  final String? notes;
  final String? performedBy;
  final DateTime? createdAt;

  factory InventoryTransaction.fromMap(Map<String, dynamic> m) {
    return InventoryTransaction(
      id: m['id'] as String,
      organizationId: m['organization_id'] as String,
      sparePartId: m['spare_part_id'] as String,
      txnType: m['txn_type'] as String,
      quantity: (m['quantity'] as num).toDouble(),
      unitCost: m['unit_cost'] is num ? (m['unit_cost'] as num).toDouble() : null,
      reference: m['reference'] as String?,
      workOrderId: m['work_order_id'] as String?,
      notes: m['notes'] as String?,
      performedBy: m['performed_by'] as String?,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())
          : null,
    );
  }
}

class PartCategories {
  static const values = [
    'Filters',
    'Oils & Fluids',
    'Electrical',
    'Mechanical',
    'Consumables',
    'Other',
  ];
}
