import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'inventory_models.dart';

class InventoryRepository {
  InventoryRepository(this._client);
  final SupabaseClient _client;

  Future<List<SparePart>> listParts({
    required String organizationId,
    String? query,
  }) async {
    var q = _client
        .from('spare_parts')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_active', true);

    final t = query?.trim();
    if (t != null && t.isNotEmpty) {
      q = q.or(
        'name.ilike.%$t%,part_number.ilike.%$t%,category.ilike.%$t%',
      );
    }

    final rows = await q.order('name').limit(200);
    return (rows as List)
        .map((e) => SparePart.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SparePart?> getPart(String id) async {
    final row =
        await _client.from('spare_parts').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return SparePart.fromMap(Map<String, dynamic>.from(row));
  }

  Future<SparePart> createPart({
    required String organizationId,
    required String name,
    String? partNumber,
    String? description,
    String? category,
    String unit = 'pcs',
    double quantityOnHand = 0,
    double reorderLevel = 0,
    double unitCost = 0,
    String? location,
    String? supplierName,
    String? notes,
  }) async {
    final row = await _client
        .from('spare_parts')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          if (partNumber != null && partNumber.trim().isNotEmpty)
            'part_number': partNumber.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (category != null) 'category': category,
          'unit': unit,
          'quantity_on_hand': quantityOnHand,
          'reorder_level': reorderLevel,
          'unit_cost': unitCost,
          if (location != null && location.trim().isNotEmpty)
            'location': location.trim(),
          if (supplierName != null && supplierName.trim().isNotEmpty)
            'supplier_name': supplierName.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select()
        .single();
    return SparePart.fromMap(Map<String, dynamic>.from(row));
  }

  Future<SparePart> updatePart(String id, Map<String, dynamic> patch) async {
    final row = await _client
        .from('spare_parts')
        .update({
          ...patch,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return SparePart.fromMap(Map<String, dynamic>.from(row));
  }

  Future<SparePart> applyMovement({
    required String organizationId,
    required String partId,
    required String txnType,
    required double quantity,
    double? unitCost,
    String? reference,
    String? workOrderId,
    String? notes,
    String? performedBy,
  }) async {
    final row = await _client.rpc('apply_stock_movement', params: {
      'p_org': organizationId,
      'p_part_id': partId,
      'p_txn_type': txnType,
      'p_quantity': quantity,
      'p_unit_cost': unitCost,
      'p_reference': reference,
      'p_work_order_id': workOrderId,
      'p_notes': notes,
      'p_performed_by': performedBy,
    });
    return SparePart.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<List<InventoryTransaction>> listTransactions({
    required String organizationId,
    String? partId,
  }) async {
    var q = _client
        .from('inventory_transactions')
        .select()
        .eq('organization_id', organizationId);
    if (partId != null) q = q.eq('spare_part_id', partId);
    final rows = await q.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((e) =>
            InventoryTransaction.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> countLowStock(String organizationId) async {
    final rows = await _client
        .from('spare_parts')
        .select('id, quantity_on_hand, reorder_level')
        .eq('organization_id', organizationId)
        .eq('is_active', true);
    var n = 0;
    for (final r in rows as List) {
      final m = Map<String, dynamic>.from(r as Map);
      final q = (m['quantity_on_hand'] as num?)?.toDouble() ?? 0;
      final rl = (m['reorder_level'] as num?)?.toDouble() ?? 0;
      if (q <= rl) n++;
    }
    return n;
  }

  Future<int> countParts(String organizationId) async {
    final rows = await _client
        .from('spare_parts')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('is_active', true);
    return (rows as List).length;
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(supabaseClientProvider));
});

final sparePartsListProvider =
    FutureProvider.autoDispose<List<SparePart>>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref.watch(inventoryRepositoryProvider).listParts(organizationId: org.id);
});

final sparePartByIdProvider =
    FutureProvider.autoDispose.family<SparePart?, String>((ref, id) {
  return ref.watch(inventoryRepositoryProvider).getPart(id);
});

final partTransactionsProvider =
    FutureProvider.autoDispose.family<List<InventoryTransaction>, String>((ref, partId) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return [];
  return ref
      .watch(inventoryRepositoryProvider)
      .listTransactions(organizationId: org.id, partId: partId);
});

final lowStockCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return 0;
  return ref.watch(inventoryRepositoryProvider).countLowStock(org.id);
});

final partsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final org = ref.watch(activeOrganizationProvider);
  if (org == null) return 0;
  return ref.watch(inventoryRepositoryProvider).countParts(org.id);
});
