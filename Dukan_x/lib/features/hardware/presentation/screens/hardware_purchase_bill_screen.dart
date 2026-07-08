import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/hardware_ops_repository.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

/// Purchase Bill screen — the final leg of PO → GRN → Purchase Bill pipeline.
///
/// Implements the GRN → Purchase Bill and Purchase Bill return flow
/// (bugfix.md 2.5, 2.15 / HARDWARE-005, HARDWARE-015).
///
/// Supports:
///   • List all Purchase Bills (optionally filtered by purchase order)
///   • Create a new Purchase Bill linked to a GRN
///   • Return a Purchase Bill (debit note)
class HardwarePurchaseBillScreen extends StatefulWidget {
  /// If provided, filters bills to those linked to this PO.
  final String? purchaseOrderId;

  const HardwarePurchaseBillScreen({super.key, this.purchaseOrderId});

  @override
  State<HardwarePurchaseBillScreen> createState() =>
      _HardwarePurchaseBillScreenState();
}

class _HardwarePurchaseBillScreenState
    extends State<HardwarePurchaseBillScreen> {
  final _repo = HardwareOpsRepository();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bills = const [];
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
        _repo.listPurchaseBills(purchaseOrderId: widget.purchaseOrderId),
        _repo.listGrn(purchaseOrderId: widget.purchaseOrderId),
        _repo.listPurchaseOrdersAsMap(),
      ]);
      if (!mounted) return;
      setState(() {
        _bills = results[0];
        _grnList = results[1];
        _purchaseOrders = results[2];
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
              ? 'Purchase Bills — PO ${_truncateId(widget.purchaseOrderId!)}'
              : 'Purchase Bills',
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
        onPressed: _showCreateBillDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Bill'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    if (_bills.isEmpty) {
      return const Center(
        child: Text(
          'No Purchase Bills found.\nCreate one from a GRN.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: DesktopContentContainer(
        maxWidth: 1000,
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: _bills.length,
          itemBuilder: (context, index) => _billCard(_bills[index]),
        ),
      ),
    );
  }

  Widget _billCard(Map<String, dynamic> bill) {
    final id = (bill['id'] ?? '').toString();
    final poId = (bill['purchaseOrderId'] ?? bill['purchase_order_id'] ?? '')
        .toString();
    final grnId = (bill['grnId'] ?? bill['grn_id'] ?? '').toString();
    final invoiceNo = (bill['invoiceNumber'] ?? bill['invoice_number'] ?? '')
        .toString();
    final items = (bill['billedItems'] ?? bill['billed_items'] ?? []) as List;
    final status = (bill['status'] ?? 'active').toString();
    final notes = (bill['notes'] ?? '').toString();

    final isReturned = status == 'returned';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isReturned
              ? Colors.red.withValues(alpha: 0.12)
              : Colors.deepPurple.withValues(alpha: 0.12),
          child: Icon(
            isReturned ? Icons.undo : Icons.receipt_long,
            color: isReturned ? Colors.red : Colors.deepPurple,
          ),
        ),
        title: Text(
          invoiceNo.isNotEmpty ? 'Bill #$invoiceNo' : 'Bill ${_truncateId(id)}',
        ),
        subtitle: Text(
          'GRN: ${_truncateId(grnId)} · PO: ${_truncateId(poId)} · '
          'Items: ${items.length}'
          '${notes.isNotEmpty ? '\n$notes' : ''}'
          '${isReturned ? '\n⚠ RETURNED' : ''}',
        ),
        isThreeLine: true,
        trailing: isReturned
            ? const Chip(label: Text('Returned'))
            : TextButton(
                onPressed: () => _showReturnDialog(id),
                child: const Text('Return'),
              ),
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

  Future<void> _showCreateBillDialog() async {
    if (_grnList.isEmpty) {
      _notify('No GRNs available. Create a GRN first.');
      return;
    }
    if (_purchaseOrders.isEmpty) {
      _notify('No purchase orders available.');
      return;
    }

    String selectedPoId =
        widget.purchaseOrderId ?? _purchaseOrders.first['id'].toString();
    String selectedGrnId = _grnList.first['id'].toString();
    final itemName = TextEditingController();
    final itemQty = TextEditingController(text: '1');
    final itemRate = TextEditingController();
    final invoiceNumber = TextEditingController();
    final notes = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Purchase Bill'),
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
                              'PO ${_truncateId(po['id'].toString())}',
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
                DropdownButtonFormField<String>(
                  value: selectedGrnId,
                  items: _grnList
                      .map(
                        (g) => DropdownMenuItem<String>(
                          value: g['id'].toString(),
                          child: Text('GRN ${_truncateId(g['id'].toString())}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setLocal(() => selectedGrnId = v ?? selectedGrnId),
                  decoration: const InputDecoration(
                    labelText: 'GRN *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: invoiceNumber,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Invoice Number',
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: itemQty,
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: itemRate,
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
    final rate = double.tryParse(itemRate.text.trim()) ?? 0;
    if (itemName.text.trim().isEmpty || qty <= 0 || rate <= 0) {
      _notify('Fill in item name, quantity and rate.');
      return;
    }

    try {
      await _repo.createPurchaseBill(
        purchaseOrderId: selectedPoId,
        grnId: selectedGrnId,
        billedItems: [
          {
            'name': itemName.text.trim(),
            'quantity': qty,
            'rate': rate,
            'amount': qty * rate,
          },
        ],
        invoiceNumber: invoiceNumber.text.trim().isEmpty
            ? null
            : invoiceNumber.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
      _notify('Purchase Bill created');
      await _load();
    } on HardwareOpsException catch (e) {
      _notify('Failed: ${e.message}');
    }
  }

  Future<void> _showReturnDialog(String billId) async {
    final itemName = TextEditingController();
    final itemQty = TextEditingController(text: '1');
    final reason = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Purchase Bill'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemName,
                decoration: const InputDecoration(
                  labelText: 'Returned item name *',
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
                  labelText: 'Returned quantity *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason for return',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (submit != true) return;

    final qty = double.tryParse(itemQty.text.trim()) ?? 0;
    if (itemName.text.trim().isEmpty || qty <= 0) {
      _notify('Fill in item name and quantity for return.');
      return;
    }

    try {
      await _repo.returnPurchaseBill(
        billId: billId,
        returnedItems: [
          {'name': itemName.text.trim(), 'quantity': qty},
        ],
        reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
      );
      _notify('Purchase Bill returned');
      await _load();
    } on HardwareOpsException catch (e) {
      _notify('Return failed: ${e.message}');
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
