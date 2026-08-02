class Vendor {
  const Vendor({
    required this.id,
    required this.organizationId,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.country,
    this.taxId,
    this.paymentTerms,
    this.category,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? country;
  final String? taxId;
  final String? paymentTerms;
  final String? category;
  final String? notes;
  final bool isActive;

  factory Vendor.fromMap(Map<String, dynamic> m) => Vendor(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        name: m['name'] as String,
        contactName: m['contact_name'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        address: m['address'] as String?,
        city: m['city'] as String?,
        country: m['country'] as String?,
        taxId: m['tax_id'] as String?,
        paymentTerms: m['payment_terms'] as String?,
        category: m['category'] as String?,
        notes: m['notes'] as String?,
        isActive: m['is_active'] as bool? ?? true,
      );

  String get subtitle {
    final parts = <String>[
      if (category != null && category!.isNotEmpty) category!,
      if (phone != null && phone!.isNotEmpty) phone!,
      if (email != null && email!.isNotEmpty) email!,
    ];
    return parts.isEmpty ? 'Vendor' : parts.join(' · ');
  }
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.organizationId,
    required this.poNumber,
    this.vendorId,
    this.vendorName,
    this.status = 'draft',
    this.currency = 'KES',
    this.notes,
    this.expectedDate,
    this.orderedBy,
    this.totalAmount = 0,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String poNumber;
  final String? vendorId;
  final String? vendorName;
  final String status;
  final String currency;
  final String? notes;
  final DateTime? expectedDate;
  final String? orderedBy;
  final double totalAmount;
  final DateTime? createdAt;

  factory PurchaseOrder.fromMap(Map<String, dynamic> m) => PurchaseOrder(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        poNumber: m['po_number'] as String,
        vendorId: m['vendor_id'] as String?,
        vendorName: m['vendor_name'] as String?,
        status: m['status'] as String? ?? 'draft',
        currency: m['currency'] as String? ?? 'KES',
        notes: m['notes'] as String?,
        expectedDate: m['expected_date'] != null
            ? DateTime.tryParse(m['expected_date'].toString())
            : null,
        orderedBy: m['ordered_by'] as String?,
        totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString())
            : null,
      );

  bool get canApprove => status == 'draft' || status == 'submitted';
  bool get canOrder => status == 'approved';
  bool get canReceive =>
      status == 'ordered' || status == 'partially_received' || status == 'approved';
  bool get isOpen => !const {'received', 'cancelled'}.contains(status);
}

class PoLineItem {
  const PoLineItem({
    required this.id,
    required this.organizationId,
    required this.purchaseOrderId,
    required this.description,
    this.sparePartId,
    this.partNumber,
    this.quantity = 1,
    this.unitCost = 0,
    this.qtyReceived = 0,
    this.lineTotal = 0,
  });

  final String id;
  final String organizationId;
  final String purchaseOrderId;
  final String description;
  final String? sparePartId;
  final String? partNumber;
  final double quantity;
  final double unitCost;
  final double qtyReceived;
  final double lineTotal;

  factory PoLineItem.fromMap(Map<String, dynamic> m) => PoLineItem(
        id: m['id'] as String,
        organizationId: m['organization_id'] as String,
        purchaseOrderId: m['purchase_order_id'] as String,
        description: m['description'] as String? ?? '',
        sparePartId: m['spare_part_id'] as String?,
        partNumber: m['part_number'] as String?,
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
        unitCost: (m['unit_cost'] as num?)?.toDouble() ?? 0,
        qtyReceived: (m['qty_received'] as num?)?.toDouble() ?? 0,
        lineTotal: (m['line_total'] as num?)?.toDouble() ?? 0,
      );

  double get remaining => quantity - qtyReceived;
}

class PoDraftLine {
  PoDraftLine({
    required this.description,
    this.sparePartId,
    this.partNumber,
    this.quantity = 1,
    this.unitCost = 0,
  });

  String description;
  String? sparePartId;
  String? partNumber;
  double quantity;
  double unitCost;

  double get lineTotal => quantity * unitCost;
}
