import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/hardware_ops_repository.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

/// GRN (Goods Receipt Note) screen — linked to purchase orders.
///
/// Implements the PO → GRN leg of the PO → GRN → Purchase Bill pipeline
/// (bugfix.md 2.5, 2.15 / HARDWARE-005, HARDWARE-015).
///
/// Supports:
///   • List all GRNs (optionally filtered by a purchase order)
///   • Create a new GRN against a specific purchase order
class HardwareGrnScreen extends StatefulWidget {
  /// If provided, filters GRNs to only those linked to this PO.
  final String? purchaseOrderId;

  const HardwareGrnScreen({super.key, this.purchaseOrderId});

  @override
  State<HardwareGrnScreen> createState() => _HardwareGrnScreenState();
}

class _HardwareGrnScreenState extends State<HardwareGrnScreen> {
  final _repo = HardwareOpsRepository();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _grnList = const [];
  List<Map<String, dynamic>> _purchaseOrders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listGrn(purchaseOrderId: widget.purchaseOrderId),
        _repo.listPurchaseOrdersAsMap(),
      ]);
      if (!mounted) return;
      setState(() {
        _grnList = results[0];
        _purchaseOrders = results[1];
        _loading = false;
      });
    } on HardwareOpsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.purchaseOrderId != null
              ? 'GRN — PO ${_truncateId(widget.purchaseOrderId!)}'
              : 'Goods Receipt Notes',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGrnDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create GRN'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    if (_grnList.isEmpty) {
      return const Center(
        child: Text('No GRNs found. Create one from a Purchase Order.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: DesktopContentContainer(
        maxWidth: 1000,
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: _grnList.length,
          itemBuilder: (context, index) {
            final grn = _grnList[index];
            return _grnCard(grn);
          },
        ),
      ),
    );
  }

  Widget _grnCard(Map<String, dynamic> grn) {
    final id = (grn['id'] ?? '').toString();
    final poId = (grn['purchaseOrderId'] ?? grn['purchase_order_id'] ?? '')
        .toString();
    final notes = (grn['notes'] ?? '').toString();
    final items = (grn['receivedItems'] ?? grn['received_items'] ?? []) as List;
    final createdAt = grn['createdAt'] ?? grn['created_at'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withValues(alpha: 0.12),
          child: const Icon(Icons.inventory_2, color: Colors.teal),
        ),
        title: Text('GRN ${_truncateId(id)}'),
        subtitle: Text(
          'PO: ${_truncateId(poId)} · Items: ${items.length}'
          '${notes.isNotEmpty ? ' · $notes' : ''}'
          '${createdAt.toString().isNotEmpty ? '\n$createdAt' : ''}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Create Purchase Bill from this GRN',
          icon: const Icon(Icons.receipt_long, color: Colors.deepPurple),
          onPressed: () => _navigateToPurchaseBill(poId, id),
        ),
      ),
    );
  }

  void _navigateToPurchaseBill(String poId, String grnId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PurchaseBillFromGrnScreen(purchaseOrderId: poId, grnId: grnId),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateGrnDialog() async {
    if (_purchaseOrders.isEmpty) {
      _notify('No purchase orders available. Create a PO first.');
      return;
    }

    String selectedPoId =
        widget.purchaseOrderId ?? _purchaseOrders.first['id'].toString();
    final itemName = TextEditingController();
    final itemQty = TextEditingController(text: '1');
    final notes = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create GRN'),
        content: StatefulBuilder(
          builder: (context, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.purchaseOrderId == null)
                  DropdownButtonFormField<String>(
                    value: selectedPoId,
                    items: _purchaseOrders
                        .map(
                          (po) => DropdownMenuItem<String>(
                            value: po['id'].toString(),
                            child: Text(
                              'PO ${_truncateId(po['id'].toString())} '
                              '(${po['status'] ?? 'pending'})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setLocal(() => selectedPoId = v ?? selectedPoId),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Order *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: itemName,
                  decoration: const InputDecoration(
                    labelText: 'Item name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: itemQty,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Quantity received *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (submit != true) return;

    final qty = double.tryParse(itemQty.text.trim()) ?? 0;
    if (itemName.text.trim().isEmpty || qty <= 0) {
      _notify('Invalid GRN data — item name and quantity are required.');
      return;
    }

    try {
      await _repo.createGrn(
        purchaseOrderId: selectedPoId,
        receivedItems: [
          {'name': itemName.text.trim(), 'quantity': qty},
        ],
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
      _notify('GRN created successfully');
      await _load();
    } on HardwareOpsException catch (e) {
      _notify('GRN creation failed: ${e.message}');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _truncateId(String id) =>
      id.length > 8 ? '${id.substring(0, 8)}…' : id;
}

// =============================================================================
// Inline helper screen: create Purchase Bill from a specific GRN.
// This is shown when tapping the receipt icon on a GRN card; the full-featured
// Purchase Bill screen is HardwarePurchaseBillScreen (separate file).
// =============================================================================
class _PurchaseBillFromGrnScreen extends StatelessWidget {
  final String purchaseOrderId;
  final String grnId;

  const _PurchaseBillFromGrnScreen({
    required this.purchaseOrderId,
    required this.grnId,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to the full Purchase Bill screen with context.
    return HardwarePurchaseBillScreenInline(
      purchaseOrderId: purchaseOrderId,
      grnId: grnId,
    );
  }
}

/// Inline Purchase Bill creation screen used from within the GRN flow.
/// For the standalone screen, see `hardware_purchase_bill_screen.dart`.
class HardwarePurchaseBillScreenInline extends StatefulWidget {
  final String purchaseOrderId;
  final String grnId;

  const HardwarePurchaseBillScreenInline({
    super.key,
    required this.purchaseOrderId,
    required this.grnId,
  });

  @override
  State<HardwarePurchaseBillScreenInline> createState() =>
      _HardwarePurchaseBillScreenInlineState();
}

class _HardwarePurchaseBillScreenInlineState
    extends State<HardwarePurchaseBillScreenInline> {
  final _repo = HardwareOpsRepository();
  final _itemName = TextEditingController();
  final _itemQty = TextEditingController(text: '1');
  final _itemRate = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _notes = TextEditingController();

  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Purchase Bill — GRN ${widget.grnId.length > 8 ? widget.grnId.substring(0, 8) : widget.grnId}…',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PO: ${widget.purchaseOrderId.length > 8 ? widget.purchaseOrderId.substring(0, 8) : widget.purchaseOrderId}…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _invoiceNumber,
              decoration: const InputDecoration(
                labelText: 'Supplier Invoice Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _itemName,
              decoration: const InputDecoration(
                labelText: 'Item name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemQty,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Qty *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _itemRate,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Rate (₹) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.save),
              label: Text(_submitting ? 'Saving…' : 'Create Purchase Bill'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_itemQty.text.trim()) ?? 0;
    final rate = double.tryParse(_itemRate.text.trim()) ?? 0;
    if (_itemName.text.trim().isEmpty || qty <= 0 || rate <= 0) {
      _notify('Fill in item name, quantity and rate.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _repo.createPurchaseBill(
        purchaseOrderId: widget.purchaseOrderId,
        grnId: widget.grnId,
        billedItems: [
          {
            'name': _itemName.text.trim(),
            'quantity': qty,
            'rate': rate,
            'amount': qty * rate,
          },
        ],
        invoiceNumber: _invoiceNumber.text.trim().isEmpty
            ? null
            : _invoiceNumber.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) {
        _notify('Purchase Bill created');
        Navigator.pop(context);
      }
    } on HardwareOpsException catch (e) {
      _notify('Failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
