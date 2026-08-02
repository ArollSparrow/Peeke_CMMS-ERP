import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/gloss_theme.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../org/org_providers.dart';
import 'procurement_models.dart';
import 'procurement_providers.dart';

class ProcurementHubScreen extends ConsumerWidget {
  const ProcurementHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openPoCountProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Procurement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _t(context, Icons.storefront_outlined, 'Vendors', 'Supplier register', '/procurement/vendors'),
          _t(context, Icons.receipt_long_outlined, 'Purchase orders',
              open == null ? 'Create & track POs' : '$open open', '/procurement/orders'),
          _t(context, Icons.add_shopping_cart_outlined, 'New purchase order',
              'Vendor + line items', '/procurement/orders/new'),
        ],
      ),
    );
  }

  Widget _t(BuildContext c, IconData i, String t, String s, String r) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(i, color: GlossColors.accent),
          title: Text(t),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => c.push(r),
        ),
      );
}

class VendorsListScreen extends ConsumerWidget {
  const VendorsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          IconButton(onPressed: () => context.push('/procurement/vendors/new'), icon: const Icon(Icons.add)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vendorsListProvider);
          await ref.read(vendorsListProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Text('$e')]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 48),
                const Center(child: Text('No vendors yet')),
                Center(child: FilledButton(
                  onPressed: () => context.push('/procurement/vendors/new'),
                  child: const Text('Add vendor'),
                )),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final v = items[i];
                return Card(
                  child: ListTile(
                    title: Text(v.name),
                    subtitle: Text(v.subtitle, style: const TextStyle(color: GlossColors.muted)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/procurement/vendors/${v.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/procurement/vendors/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class VendorFormScreen extends ConsumerStatefulWidget {
  const VendorFormScreen({super.key, this.vendorId});
  final String? vendorId;
  bool get isEdit => vendorId != null;

  @override
  ConsumerState<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends ConsumerState<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _terms = TextEditingController();
  final _notes = TextEditingController();
  String? _category = 'Parts';
  bool _loading = false;
  bool _hydrated = false;

  @override
  void dispose() {
    for (final c in [_name, _contact, _phone, _email, _address, _terms, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(Vendor v) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = v.name;
    _contact.text = v.contactName ?? '';
    _phone.text = v.phone ?? '';
    _email.text = v.email ?? '';
    _address.text = v.address ?? '';
    _terms.text = v.paymentTerms ?? '';
    _notes.text = v.notes ?? '';
    _category = v.category ?? 'Parts';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(procurementRepositoryProvider);
      late Vendor saved;
      if (widget.isEdit) {
        saved = await repo.updateVendor(widget.vendorId!, {
          'name': _name.text.trim(),
          'contact_name': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
          'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
          'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
          'payment_terms': _terms.text.trim().isEmpty ? null : _terms.text.trim(),
          'category': _category,
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        });
      } else {
        saved = await repo.createVendor(
          organizationId: org.id,
          name: _name.text,
          contactName: _contact.text,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
          paymentTerms: _terms.text,
          category: _category,
          notes: _notes.text,
        );
      }
      ref.invalidate(vendorsListProvider);
      if (!mounted) return;
      context.go('/procurement/vendors/${saved.id}');
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
      ref.watch(vendorByIdProvider(widget.vendorId!)).whenData((v) {
        if (v != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hydrate(v));
          });
        }
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit vendor' : 'Add vendor')),
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
            TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact person')),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const ['Parts', 'Services', 'Consumables', 'Equipment', 'Other']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _terms, decoration: const InputDecoration(labelText: 'Payment terms')),
            const SizedBox(height: 12),
            TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.isEdit ? 'Update' : 'Save vendor'),
          ),
        ),
      ),
    );
  }
}

class VendorDetailScreen extends ConsumerWidget {
  const VendorDetailScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorByIdProvider(vendorId));
    return Scaffold(
      appBar: AppBar(
        title: async.when(
          data: (v) => Text(v?.name ?? 'Vendor'),
          loading: () => const Text('Vendor'),
          error: (_, __) => const Text('Vendor'),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/procurement/vendors/$vendorId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (v) {
          if (v == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _row('Category', v.category),
              _row('Contact', v.contactName),
              _row('Phone', v.phone),
              _row('Email', v.email),
              _row('Payment terms', v.paymentTerms),
              _row('Address', v.address),
              _row('Notes', v.notes),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/procurement/orders/new?vendorId=${v.id}'),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('New PO for this vendor'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String l, String? v) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(l, style: const TextStyle(fontSize: 12, color: GlossColors.muted)),
        subtitle: Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: GlossColors.ink)),
      ),
    );
  }
}

class PurchaseOrdersListScreen extends ConsumerWidget {
  const PurchaseOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseOrdersListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase orders'),
        actions: [
          IconButton(onPressed: () => context.push('/procurement/orders/new'), icon: const Icon(Icons.add)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(purchaseOrdersListProvider);
          await ref.read(purchaseOrdersListProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Text('$e')]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 48),
                const Center(child: Text('No purchase orders yet')),
                Center(child: FilledButton(
                  onPressed: () => context.push('/procurement/orders/new'),
                  child: const Text('Create PO'),
                )),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final po = items[i];
                return Card(
                  child: ListTile(
                    title: Text(po.poNumber),
                    subtitle: Text(
                      '${po.vendorName ?? 'No vendor'} · ${po.currency} ${po.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: GlossColors.muted),
                    ),
                    trailing: Chip(
                      label: Text(po.status, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () => context.push('/procurement/orders/${po.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/procurement/orders/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key, this.preselectedVendorId});
  final String? preselectedVendorId;

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends ConsumerState<PurchaseOrderFormScreen> {
  final _notes = TextEditingController();
  Vendor? _vendor;
  final List<PoDraftLine> _lines = [];
  bool _loading = false;
  bool _vendorPicked = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final parts = ref.read(sparePartsListProvider).valueOrNull ?? [];
    final desc = TextEditingController();
    final qty = TextEditingController(text: '1');
    final cost = TextEditingController(text: '0');
    SparePart? selected;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add line'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (parts.isNotEmpty)
                  DropdownButtonFormField<SparePart>(
                    decoration: const InputDecoration(labelText: 'From catalogue'),
                    items: parts
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (p) {
                      setLocal(() {
                        selected = p;
                        if (p != null) {
                          desc.text = p.name;
                          cost.text = p.unitCost.toString();
                        }
                      });
                    },
                  ),
                TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description *')),
                TextFormField(
                  controller: qty,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: cost,
                  decoration: const InputDecoration(labelText: 'Unit cost'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || desc.text.trim().isEmpty) return;
    setState(() {
      _lines.add(PoDraftLine(
        description: desc.text.trim(),
        sparePartId: selected?.id,
        partNumber: selected?.partNumber,
        quantity: double.tryParse(qty.text) ?? 1,
        unitCost: double.tryParse(cost.text) ?? 0,
      ));
    });
  }

  Future<void> _save() async {
    final org = ref.read(activeOrganizationProvider);
    if (org == null) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one line')));
      return;
    }
    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider);
      final po = await ref.read(procurementRepositoryProvider).createOrder(
            organizationId: org.id,
            vendorId: _vendor?.id,
            vendorName: _vendor?.name,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            orderedBy: user?.email,
            lines: _lines,
          );
      ref.invalidate(purchaseOrdersListProvider);
      ref.invalidate(openPoCountProvider);
      if (!mounted) return;
      context.go('/procurement/orders/${po.id}');
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
    final vendors = ref.watch(vendorsListProvider).valueOrNull ?? [];
    if (!_vendorPicked && widget.preselectedVendorId != null) {
      final match = vendors.where((v) => v.id == widget.preselectedVendorId);
      if (match.isNotEmpty) {
        _vendor = match.first;
        _vendorPicked = true;
      }
    }
    final total = _lines.fold<double>(0, (s, l) => s + l.lineTotal);

    return Scaffold(
      appBar: AppBar(title: const Text('New purchase order')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          DropdownButtonFormField<Vendor>(
            value: _vendor != null && vendors.any((v) => v.id == _vendor!.id)
                ? vendors.firstWhere((v) => v.id == _vendor!.id)
                : null,
            decoration: const InputDecoration(labelText: 'Vendor'),
            items: vendors.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
            onChanged: (v) => setState(() => _vendor = v),
          ),
          if (vendors.isEmpty)
            TextButton(
              onPressed: () => context.push('/procurement/vendors/new'),
              child: const Text('Register a vendor first'),
            ),
          const SizedBox(height: 12),
          TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
          const SizedBox(height: 16),
          Row(children: [
            const Text('LINES',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlossColors.muted)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add line'),
            ),
          ]),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No lines yet — add catalogue parts or free text.',
                  style: TextStyle(color: GlossColors.muted)),
            ),
          for (var i = 0; i < _lines.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_lines[i].description),
                subtitle: Text(
                  'Qty ${_lines[i].quantity} × ${_lines[i].unitCost} = ${_lines[i].lineTotal.toStringAsFixed(2)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _lines.removeAt(i)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text('Total: ${total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create draft PO'),
          ),
        ),
      ),
    );
  }
}

class PurchaseOrderDetailScreen extends ConsumerWidget {
  const PurchaseOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  Future<void> _status(BuildContext context, WidgetRef ref, String status) async {
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(procurementRepositoryProvider).updateStatus(
            orderId,
            status: status,
            approvedBy: user?.email,
          );
      ref.invalidate(purchaseOrderByIdProvider(orderId));
      ref.invalidate(purchaseOrdersListProvider);
      ref.invalidate(openPoCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status → $status')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _receive(BuildContext context, WidgetRef ref) async {
    final org = ref.read(activeOrganizationProvider);
    final user = ref.read(currentUserProvider);
    if (org == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive goods'),
        content: const Text(
          'This will mark remaining quantities received and increase stock for linked spare parts.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Receive')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(procurementRepositoryProvider).receiveOrder(
            organizationId: org.id,
            poId: orderId,
            performedBy: user?.email,
          );
      ref.invalidate(purchaseOrderByIdProvider(orderId));
      ref.invalidate(poLinesProvider(orderId));
      ref.invalidate(purchaseOrdersListProvider);
      ref.invalidate(openPoCountProvider);
      ref.invalidate(sparePartsListProvider);
      ref.invalidate(partsCountProvider);
      ref.invalidate(lowStockCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goods received into inventory')),
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
    final poAsync = ref.watch(purchaseOrderByIdProvider(orderId));
    final linesAsync = ref.watch(poLinesProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: poAsync.when(
          data: (p) => Text(p?.poNumber ?? 'PO'),
          loading: () => const Text('PO'),
          error: (_, __) => const Text('PO'),
        ),
      ),
      body: poAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (po) {
          if (po == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(po.status.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: GlossColors.accent)),
                  subtitle: Text(
                      '${po.vendorName ?? 'No vendor'} · ${po.currency} ${po.totalAmount.toStringAsFixed(2)}'),
                ),
              ),
              if (po.notes != null && po.notes!.isNotEmpty)
                Card(
                  child: ListTile(
                    title: const Text('Notes', style: TextStyle(fontSize: 12, color: GlossColors.muted)),
                    subtitle: Text(po.notes!),
                  ),
                ),
              const SizedBox(height: 8),
              const Text('LINES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlossColors.muted)),
              const SizedBox(height: 8),
              linesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (lines) {
                  if (lines.isEmpty) {
                    return const Text('No lines', style: TextStyle(color: GlossColors.muted));
                  }
                  return Column(
                    children: [
                      for (final l in lines)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(l.description),
                            subtitle: Text(
                              'Qty ${l.quantity} · recv ${l.qtyReceived} · '
                              '@ ${l.unitCost} = ${l.lineTotal.toStringAsFixed(2)}',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('ACTIONS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlossColors.muted)),
              const SizedBox(height: 8),
              if (po.canApprove) ...[
                FilledButton(
                  onPressed: () => _status(context, ref, 'approved'),
                  child: const Text('Approve'),
                ),
                const SizedBox(height: 8),
              ],
              if (po.canOrder) ...[
                FilledButton(
                  onPressed: () => _status(context, ref, 'ordered'),
                  child: const Text('Mark ordered'),
                ),
                const SizedBox(height: 8),
              ],
              if (po.canReceive) ...[
                FilledButton.tonal(
                  onPressed: () => _receive(context, ref),
                  child: const Text('Receive into inventory'),
                ),
                const SizedBox(height: 8),
              ],
              if (po.isOpen)
                TextButton(
                  onPressed: () => _status(context, ref, 'cancelled'),
                  child: const Text('Cancel PO', style: TextStyle(color: GlossColors.danger)),
                ),
            ],
          );
        },
      ),
    );
  }
}
