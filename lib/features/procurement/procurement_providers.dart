import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'procurement_models.dart';

class ProcurementRepository {
  ProcurementRepository(this._client);
  final SupabaseClient _client;

  // —— Vendors ——
  Future<List<Vendor>> listVendors(String orgId) async {
    final rows = await _client
        .from('vendors')
        .select()
        .eq('organization_id', orgId)
        .eq('is_active', true)
        .order('name');
    return (rows as List)
        .map((e) => Vendor.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Vendor?> getVendor(String id) async {
    final row =
        await _client.from('vendors').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Vendor.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Vendor> createVendor({
    required String organizationId,
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    String? category,
    String? notes,
  }) async {
    final row = await _client
        .from('vendors')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          if (contactName != null) 'contact_name': contactName.trim(),
          if (phone != null) 'phone': phone.trim(),
          if (email != null) 'email': email.trim(),
          if (address != null) 'address': address.trim(),
          if (paymentTerms != null) 'payment_terms': paymentTerms.trim(),
          if (category != null) 'category': category,
          if (notes != null) 'notes': notes.trim(),
        })
        .select()
        .single();
    return Vendor.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Vendor> updateVendor(String id, Map<String, dynamic> patch) async {
    final row = await _client
        .from('vendors')
        .update({...patch, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Vendor.fromMap(Map<String, dynamic>.from(row));
  }

  // —— Purchase orders ——
  Future<List<PurchaseOrder>> listOrders(String orgId) async {
    final rows = await _client
        .from('purchase_orders')
        .select()
        .eq('organization_id', orgId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => PurchaseOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PurchaseOrder?> getOrder(String id) async {
    final row = await _client
        .from('purchase_orders')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return PurchaseOrder.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<PoLineItem>> listLines(String poId) async {
    final rows = await _client
        .from('po_line_items')
        .select()
        .eq('purchase_order_id', poId)
        .order('created_at');
    return (rows as List)
        .map((e) => PoLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> _nextPoNumber(String orgId) async {
    final n = await _client.rpc('next_po_number', params: {'p_org': orgId});
    return n as String;
  }

  Future<PurchaseOrder> createOrder({
    required String organizationId,
    String? vendorId,
    String? vendorName,
    String? notes,
    String? orderedBy,
    List<PoDraftLine> lines = const [],
  }) async {
    final number = await _nextPoNumber(organizationId);
    final total = lines.fold<double>(0, (s, l) => s + l.lineTotal);
    final row = await _client
        .from('purchase_orders')
        .insert({
          'organization_id': organizationId,
          'po_number': number,
          if (vendorId != null) 'vendor_id': vendorId,
          if (vendorName != null) 'vendor_name': vendorName,
          if (notes != null) 'notes': notes,
          if (orderedBy != null) 'ordered_by': orderedBy,
          'status': 'draft',
          'total_amount': total,
        })
        .select()
        .single();
    final po = PurchaseOrder.fromMap(Map<String, dynamic>.from(row));

    if (lines.isNotEmpty) {
      await _client.from('po_line_items').insert([
        for (final l in lines)
          {
            'organization_id': organizationId,
            'purchase_order_id': po.id,
            'description': l.description.trim(),
            if (l.sparePartId != null) 'spare_part_id': l.sparePartId,
            if (l.partNumber != null) 'part_number': l.partNumber,
            'quantity': l.quantity,
            'unit_cost': l.unitCost,
          },
      ]);
    }
    return po;
  }

  Future<PurchaseOrder> updateStatus(
    String id, {
    required String status,
    String? approvedBy,
  }) async {
    final patch = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status == 'approved') {
      patch['approved_by'] = approvedBy;
      patch['approved_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'ordered') {
      patch['ordered_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'cancelled') {
      patch['cancelled_at'] = DateTime.now().toUtc().toIso8601String();
    }
    final row = await _client
        .from('purchase_orders')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return PurchaseOrder.fromMap(Map<String, dynamic>.from(row));
  }

  Future<PurchaseOrder> receiveOrder({
    required String organizationId,
    required String poId,
    String? performedBy,
  }) async {
    final row = await _client.rpc('receive_po_lines', params: {
      'p_org': organizationId,
      'p_po_id': poId,
      'p_performed_by': performedBy,
    });
    return PurchaseOrder.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<int> countOpenPos(String orgId) async {
    final rows = await _client
        .from('purchase_orders')
        .select('id')
        .eq('organization_id', orgId)
        .inFilter('status', [
      'draft',
      'submitted',
      'approved',
      'ordered',
      'partially_received',
    ]);
    return (rows as List).length;
  }
}

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  return ProcurementRepository(ref.watch(supabaseClientProvider));
});

final vendorsListProvider =
    FutureProvider.autoDispose<List<Vendor>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(procurementRepositoryProvider).listVendors(org.id);
});

final vendorByIdProvider =
    FutureProvider.autoDispose.family<Vendor?, String>((ref, id) {
  return ref.watch(procurementRepositoryProvider).getVendor(id);
});

final purchaseOrdersListProvider =
    FutureProvider.autoDispose<List<PurchaseOrder>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(procurementRepositoryProvider).listOrders(org.id);
});

final purchaseOrderByIdProvider =
    FutureProvider.autoDispose.family<PurchaseOrder?, String>((ref, id) {
  return ref.watch(procurementRepositoryProvider).getOrder(id);
});

final poLinesProvider =
    FutureProvider.autoDispose.family<List<PoLineItem>, String>((ref, poId) {
  return ref.watch(procurementRepositoryProvider).listLines(poId);
});

final openPoCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return 0;
  return ref.watch(procurementRepositoryProvider).countOpenPos(org.id);
});
