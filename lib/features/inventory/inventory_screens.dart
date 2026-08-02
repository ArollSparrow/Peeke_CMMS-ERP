import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../org/org_providers.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class InventoryHubScreen extends ConsumerWidget {
  const InventoryHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = ref.watch(partsCountProvider).valueOrNull;
    final low = ref.watch(lowStockCountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context, Icons.inventory_2_outlined, 'Spare parts',
              parts == null ? 'Catalogue' : '$parts active', '/inventory/parts'),
          _tile(context, Icons.add_box_outlined, 'Add part',
              'New catalogue item', '/inventory/parts/new'),
          _tile(
            context,
            Icons.warning_amber_outlined,
            'Low stock',
            low == null ? 'Below reorder level' : '$low item(s)',
            '/inventory/parts?low=1',
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub, String route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: GlossColors.accent),
        title: Text(title),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}

class SparePartsListScreen extends ConsumerStatefulWidget {
  const SparePartsListScreen({super.key, this.lowOnly = false});
  final bool lowOnly;

  @override
  ConsumerState<SparePartsListScreen> createState() => _SparePartsListScreenState();
}

class _SparePartsListScreenState extends ConsumerState<SparePartsListScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sparePartsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lowOnly ? 'Low stock' : 'Spare parts'),
        actions: [
          IconButton(
            onPressed: () => context.push('/inventory/parts/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search name, part #, category…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _q = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(sparePartsListProvider);
                await ref.read(sparePartsListProvider.future);
              },
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [Padding(
                  padding: const EdgeInsets.all(24), child: Text('$e'))]),
                data: (items) {
                  var list = items;
                  if (widget.lowOnly) {
                    list = list.where((p) => p.isLowStock).toList();
                  }
                  if (_q.isNotEmpty) {
                    list = list.where((p) {
                      final hay =
                          '${p.name} ${p.partNumber ?? ''} ${p.category ?? ''}'
                              .toLowerCase();
                      return hay.contains(_q);
                    }).toList();
                  }
                  if (list.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(items.isEmpty ? 'No parts yet' : 'No matches',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: () => context.push('/inventory/parts/new'),
                          child: const Text('Add part'),
                        ),
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return Card(
                        child: ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                            p.subtitle,
                            style: const TextStyle(color: GlossColors.muted),
                          ),
                          trailing: p.isLowStock
                              ? const Chip(
                                  label: Text('Low',
                                      style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => context.push('/inventory/parts/${p.id}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/inventory/parts/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SparePartFormScreen extends ConsumerStatefulWidget {
  const SparePartFormScreen({super.key, this.partId});
  final String? partId;
  bool get isEdit => partId != null;

  @override
  ConsumerState<SparePartFormScreen> createState() => _SparePartFormScreenState();
}

class _SparePartFormScreenState extends ConsumerState<SparePartFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _partNo = TextEditingController();
  final _desc = TextEditingController();
  final _qty = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '5');
  final _cost = TextEditingController(text: '0');
  final _location = TextEditingController();
  final _supplier = TextEditingController();
  final _notes = TextEditingController();
  String? _category = 'Other';
  bool _loading = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _partNo.dispose();
    _desc.dispose();
    _qty.dispose();
    _reorder.dispose();
    _cost.dispose();
    _location.dispose();
    _supplier.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(SparePart p) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = p.name;
    _partNo.text = p.partNumber ?? '';
    _desc.text = p.description ?? '';
    _qty.text = p.quantityOnHand.toString();
    _reorder.text = p.reorderLevel.toString();
    _cost.text = p.unitCost.toString();
    _location.text = p.location ?? '';
    _supplier.text = p.supplierName ?? '';
    _notes.text = p.notes ?? '';
    _category = p.category ?? 'Other';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      late SparePart saved;
      if (widget.isEdit) {
        saved = await repo.updatePart(widget.partId!, {
          'name': _name.text.trim(),
          'part_number': _partNo.text.trim().isEmpty ? null : _partNo.text.trim(),
          'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          'category': _category,
          'reorder_level': double.tryParse(_reorder.text) ?? 0,
          'unit_cost': double.tryParse(_cost.text) ?? 0,
          'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
          'supplier_name':
              _supplier.text.trim().isEmpty ? null : _supplier.text.trim(),
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        });
      } else {
        saved = await repo.createPart(
          organizationId: org.id,
          name: _name.text.trim(),
          partNumber: _partNo.text,
          description: _desc.text,
          category: _category,
          quantityOnHand: double.tryParse(_qty.text) ?? 0,
          reorderLevel: double.tryParse(_reorder.text) ?? 0,
          unitCost: double.tryParse(_cost.text) ?? 0,
          location: _location.text,
          supplierName: _supplier.text,
          notes: _notes.text,
        );
      }
      ref.invalidate(sparePartsListProvider);
      ref.invalidate(partsCountProvider);
      ref.invalidate(lowStockCountProvider);
      if (!mounted) return;
      context.go('/inventory/parts/${saved.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      ref.watch(sparePartByIdProvider(widget.partId!)).whenData((p) {
        if (p != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hydrate(p));
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit part' : 'Add part')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _partNo,
              decoration: const InputDecoration(labelText: 'Part number'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: PartCategories.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            if (!widget.isEdit)
              TextFormField(
                controller: _qty,
                decoration: const InputDecoration(labelText: 'Opening quantity'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            if (!widget.isEdit) const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _reorder,
                  decoration: const InputDecoration(labelText: 'Reorder level'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  decoration: const InputDecoration(labelText: 'Unit cost'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Store location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplier,
              decoration: const InputDecoration(labelText: 'Supplier'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.isEdit ? 'Update' : 'Save part'),
          ),
        ),
      ),
    );
  }
}

class SparePartDetailScreen extends ConsumerWidget {
  const SparePartDetailScreen({super.key, required this.partId});
  final String partId;

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    SparePart part,
    String txnType,
  ) async {
    final qtyCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(txnType == 'receive'
            ? 'Receive stock'
            : txnType == 'issue'
                ? 'Issue stock'
                : 'Adjust to quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: qtyCtrl,
              decoration: InputDecoration(
                labelText: txnType == 'adjust' ? 'New quantity on hand' : 'Quantity',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: refCtrl,
              decoration: const InputDecoration(labelText: 'Reference (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    final qty = double.tryParse(qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a positive quantity')),
        );
      }
      return;
    }
    final org = ref.read(activeOrganizationProvider);
    final user = ref.read(currentUserProvider);
    if (org == null) return;
    try {
      await ref.read(inventoryRepositoryProvider).applyMovement(
            organizationId: org.id,
            partId: part.id,
            txnType: txnType,
            quantity: qty,
            reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
            performedBy: user?.email,
          );
      ref.invalidate(sparePartByIdProvider(partId));
      ref.invalidate(sparePartsListProvider);
      ref.invalidate(partTransactionsProvider(partId));
      ref.invalidate(lowStockCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$txnType recorded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partAsync = ref.watch(sparePartByIdProvider(partId));
    final txnsAsync = ref.watch(partTransactionsProvider(partId));

    return Scaffold(
      appBar: AppBar(
        title: partAsync.when(
          data: (p) => Text(p?.name ?? 'Part'),
          loading: () => const Text('Part'),
          error: (_, __) => const Text('Part'),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/inventory/parts/$partId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: partAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          if (p == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    '${p.quantityOnHand % 1 == 0 ? p.quantityOnHand.toStringAsFixed(0) : p.quantityOnHand} ${p.unit}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    p.isLowStock
                        ? 'Low stock · reorder at ${p.reorderLevel}'
                        : 'Reorder at ${p.reorderLevel}',
                    style: TextStyle(
                      color: p.isLowStock ? GlossColors.danger : GlossColors.muted,
                    ),
                  ),
                ),
              ),
              _row('Part #', p.partNumber),
              _row('Category', p.category),
              _row('Location', p.location),
              _row('Supplier', p.supplierName),
              _row('Unit cost', p.unitCost.toString()),
              _row('Description', p.description),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _move(context, ref, p, 'receive'),
                    child: const Text('Receive'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _move(context, ref, p, 'issue'),
                    child: const Text('Issue'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _move(context, ref, p, 'adjust'),
                    child: const Text('Adjust'),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              const Text('MOVEMENTS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GlossColors.muted)),
              const SizedBox(height: 8),
              txnsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (txns) {
                  if (txns.isEmpty) {
                    return const Text('No movements yet',
                        style: TextStyle(color: GlossColors.muted));
                  }
                  return Column(
                    children: [
                      for (final t in txns)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(
                                '${t.txnType} · ${t.quantity % 1 == 0 ? t.quantity.toStringAsFixed(0) : t.quantity}'),
                            subtitle: Text([
                              if (t.reference != null) t.reference!,
                              if (t.performedBy != null) t.performedBy!,
                              if (t.createdAt != null)
                                t.createdAt!.toLocal().toString().split('.').first,
                            ].join(' · ')),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 12, color: GlossColors.muted)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: GlossColors.ink)),
      ),
    );
  }
}
