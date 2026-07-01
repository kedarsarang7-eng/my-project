import 'package:flutter/material.dart';
import '../core/theme/futuristic_colors.dart';
import '../services/customer_panel_pdf_service.dart';

/// Dialog to edit bill items
class EditBillItemDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onSave;

  const EditBillItemDialog({
    super.key,
    required this.item,
    required this.onSave,
  });

  @override
  State<EditBillItemDialog> createState() => _EditBillItemDialogState();
}

class _EditBillItemDialogState extends State<EditBillItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['vegName'] ?? '');
    _priceController = TextEditingController(
      text: (widget.item['pricePerKg'] ?? 0).toString(),
    );
    _qtyController = TextEditingController(
      text: (widget.item['quantity'] ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _save() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final qty = double.tryParse(_qtyController.text) ?? 0;

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter item name')));
      return;
    }

    widget.onSave({
      'vegName': _nameController.text,
      'pricePerKg': price,
      'quantity': qty,
      'total': price * qty,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price per KG (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity (KG)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: FuturisticColors.success,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Enhanced Customer Panel with PDF export and Excel-style bill table
class EnhancedCustomerPanel extends StatefulWidget {
  final dynamic customer;
  final List<Map<String, dynamic>> billItems;
  final double totalAmount;
  final double pendingDues;
  final String reminders;
  final Function(List<Map<String, dynamic>>) onItemsChanged;

  const EnhancedCustomerPanel({
    super.key,
    required this.customer,
    required this.billItems,
    required this.totalAmount,
    required this.pendingDues,
    required this.reminders,
    required this.onItemsChanged,
  });

  @override
  State<EnhancedCustomerPanel> createState() => _EnhancedCustomerPanelState();
}

class _EnhancedCustomerPanelState extends State<EnhancedCustomerPanel> {
  late List<Map<String, dynamic>> _items;
  late double _total;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.billItems);
    _recalculateTotal();
  }

  void _recalculateTotal() {
    _total = _items.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['pricePerKg'] ?? 0) as num) * ((item['quantity'] ?? 0) as num),
    );
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (context) => EditBillItemDialog(
        item: _items[index],
        onSave: (updatedItem) {
          setState(() {
            _items[index] = updatedItem;
            _recalculateTotal();
            widget.onItemsChanged(_items);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _recalculateTotal();
      widget.onItemsChanged(_items);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _downloadPDF() async {
    try {
      final customerName = widget.customer is Map
          ? widget.customer['name'] ?? 'Unknown'
          : widget.customer.name ?? 'Unknown';

      await CustomerPanelPdfService.generateAndDownloadBillPDF(
        customerName: customerName,
        items: _items,
        total: _total,
        pendingDues: widget.pendingDues,
        reminders: widget.reminders,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.customer is Map
        ? widget.customer['name'] ?? 'Unknown'
        : widget.customer.name ?? 'Unknown';
    final isPaid = widget.pendingDues <= 0;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with PDF button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Panel',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        customerName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                // PDF Download Button
                Tooltip(
                  message: 'Download as PDF',
                  child: ElevatedButton.icon(
                    onPressed: _downloadPDF,
                    icon: const Icon(Icons.download),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Status Cards
            Row(
              children: [
                Expanded(
                  child: _statusCard(
                    'Pending Dues',
                    '₹${widget.pendingDues.toStringAsFixed(0)}',
                    isPaid ? FuturisticColors.paid : FuturisticColors.unpaid,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statusCard(
                    'Daily Bill',
                    '₹${_total.toStringAsFixed(0)}',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statusCard(
                    'Amount Paid',
                    '₹${(_total - widget.pendingDues).toStringAsFixed(0)}',
                    FuturisticColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Daily Veg Bill Table
            Text(
              'Daily Bill (${_items.length} items)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Excel-Style Table
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  // Header Row
                  Container(
                    color: FuturisticColors.primary,
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: _tableHeaderCell('Item Name')),
                        Expanded(
                          flex: 1,
                          child: _tableHeaderCell(
                            'Price/KG',
                            align: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: _tableHeaderCell(
                            'Qty (KG)',
                            align: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _tableHeaderCell(
                            'Total',
                            align: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 60),
                      ],
                    ),
                  ),

                  // Data Rows
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'No items in bill',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final vegName = item['vegName'] ?? 'N/A';
                        final price = (item['pricePerKg'] ?? 0) as num;
                        final qty = (item['quantity'] ?? 0) as num;
                        final total = price * qty;
                        final isEven = index % 2 == 0;

                        return Container(
                          color: isEven ? Colors.white : Colors.grey[50],
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: _tableDataCell(vegName)),
                              Expanded(
                                flex: 1,
                                child: _tableDataCell(
                                  '₹${price.toStringAsFixed(0)}',
                                  align: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: _tableDataCell(
                                  qty.toStringAsFixed(2),
                                  align: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: _tableDataCell(
                                  '₹${total.toStringAsFixed(2)}',
                                  align: TextAlign.right,
                                  isBold: true,
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _editItem(index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: FuturisticColors.error,
                                      ),
                                      onPressed: () => _removeItem(index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Summary Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _summaryRow('Subtotal', _total),
                  if (widget.pendingDues > 0)
                    _summaryRow('Pending Due', widget.pendingDues, isRed: true),
                  const Divider(height: 16),
                  _summaryRow(
                    'Amount Paid',
                    _total - widget.pendingDues,
                    isBold: true,
                    isGreen: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Reminders
            if (widget.reminders.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminders',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.reminders,
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String label, String value, Color color) {
    return Card(
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _tableDataCell(
    String text, {
    TextAlign align = TextAlign.left,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isBold ? FuturisticColors.success : Colors.black,
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isRed = false,
    bool isGreen = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              color: isRed
                  ? FuturisticColors.unpaid
                  : isGreen
                  ? FuturisticColors.success
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
