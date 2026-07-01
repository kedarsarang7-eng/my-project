import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:intl/intl.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/ui/futuristic_button.dart';

class EditBillScreen extends StatefulWidget {
  final Bill bill;
  final String customerName;
  final VoidCallback? onBillUpdated;

  const EditBillScreen({
    super.key,
    required this.bill,
    required this.customerName,
    this.onBillUpdated,
  });

  @override
  State<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends State<EditBillScreen> {
  late List<BillItem> items;
  late TextEditingController discountController;
  late double subtotal;
  late double total;
  bool isSaving = false;

  final List<String> vegetables = [
    'Tomato',
    'Onion',
    'Potato',
    'Carrot',
    'Cabbage',
    'Spinach',
    'Brinjal',
    'Chilli',
    'Cucumber',
    'Bottle Gourd',
    'Bitter Gourd',
    'Pumpkin',
    'Cauliflower',
    'Radish',
    'Green Peas',
    'Lettuce',
    'Capsicum',
    'Ginger',
    'Garlic',
    'Lemon',
  ];

  @override
  void initState() {
    super.initState();
    items = List.from(widget.bill.items);
    discountController = TextEditingController(
      text: widget.bill.discountApplied.toStringAsFixed(2),
    );
    _calculateTotals();
  }

  void _calculateTotals() {
    subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    double discount = double.tryParse(discountController.text) ?? 0;
    total = subtotal - discount;
  }

  void _addNewItem() {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        vegetables: vegetables,
        onAdd: (vegName, pricePerKg, qtyKg) {
          setState(() {
            items.add(
              BillItem(
                productId: '',
                productName: vegName,
                qty: qtyKg,
                price: pricePerKg,
                unit: 'kg',
              ),
            );
            _calculateTotals();
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      items.removeAt(index);
      _calculateTotals();
    });
  }

  void _editItem(int index) {
    final item = items[index];
    showDialog(
      context: context,
      builder: (context) => _EditItemDialog(
        item: item,
        vegetables: vegetables,
        onSave: (vegName, pricePerKg, qtyKg) {
          setState(() {
            items[index] = BillItem(
              productId: item.productId,
              productName: vegName,
              qty: qtyKg,
              price: pricePerKg,
              unit: 'kg',
            );
            _calculateTotals();
          });
        },
      ),
    );
  }

  Future<void> _saveBill() async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill must have at least one item')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      double discount = double.tryParse(discountController.text) ?? 0;

      // Update bill
      // Update bill
      final updatedBill = Bill(
        id: widget.bill.id,
        customerId: widget.bill.customerId,
        customerName:
            widget.bill.customerName, // Ensure required fields are passed
        date: widget.bill.date,
        items: items,
        subtotal: subtotal,
        totalTax: widget.bill.totalTax, // Maintain fields
        grandTotal: total, // Updated total
        paidAmount: widget.bill.paidAmount,
        status: widget.bill.status,
        paymentType: widget.bill.paymentType,
        discountApplied: discount,
        marketTicket: widget.bill.marketTicket,
        cashPaid: widget.bill.cashPaid,
        onlinePaid: widget.bill.onlinePaid,
        ownerId: widget.bill.ownerId,
        shopName: widget.bill.shopName,
        shopAddress: widget.bill.shopAddress,
        shopContact: widget.bill.shopContact,
      ).sanitized();

      await sl<BillsRepository>().updateBill(updatedBill);

      if (mounted) {
        widget.onBillUpdated?.call();
        Navigator.pop(context, updatedBill);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving bill: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    final detailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Date:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(widget.bill.date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Discount
        _buildEditField(
          label: 'Discount (Rs.)',
          controller: discountController,
          onChanged: (_) => setState(() => _calculateTotals()),
        ),
        const SizedBox(height: 20),
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _summaryRow('Subtotal', subtotal),
              if ((double.tryParse(discountController.text) ?? 0) > 0)
                _summaryRow(
                  'Discount',
                  -(double.tryParse(discountController.text) ?? 0),
                  isNegative: true,
                ),
              const Divider(height: 16),
              _summaryRow('Total', total, isBold: true, fontSize: 16),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FuturisticButton.success(
                label: isSaving ? 'Saving...' : 'Save Bill',
                isLoading: isSaving,
                onPressed: isSaving ? null : _saveBill,
              ),
            ),
          ],
        ),
      ],
    );

    final itemsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Items header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bill Items (${items.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            FuturisticButton.primary(
              label: 'Add Item',
              icon: Icons.add,
              onPressed: _addNewItem,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Items list
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Text(
              'No items in bill. Add items to get started.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(item, index);
            },
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Bill'),
        backgroundColor: FuturisticColors.primary,
        elevation: 0,
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      detailsColumn,
                      const SizedBox(height: 24),
                      itemsColumn,
                      const SizedBox(height: 16),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: detailsColumn,
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 6,
                        child: itemsColumn,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(BillItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '₹${item.price.toStringAsFixed(0)}/${item.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${item.qty.toStringAsFixed(2)} ${item.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: FuturisticColors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue[600]),
                          onPressed: () => _editItem(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 18,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: FuturisticColors.error,
                          ),
                          onPressed: () => _removeItem(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixText: '₹ ',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isNegative = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isNegative ? FuturisticColors.error : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final List<String> vegetables;
  final Function(String vegName, double pricePerKg, double qtyKg) onAdd;

  const _AddItemDialog({required this.vegetables, required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late String selectedVeg;
  late TextEditingController priceController;
  late TextEditingController qtyController;

  @override
  void initState() {
    super.initState();
    selectedVeg = widget.vegetables.first;
    priceController = TextEditingController();
    qtyController = TextEditingController();
  }

  @override
  void dispose() {
    priceController.dispose();
    qtyController.dispose();
    super.dispose();
  }

  void _add() {
    final price = double.tryParse(priceController.text);
    final qty = double.tryParse(qtyController.text);

    if (price == null || qty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid price and quantity')),
      );
      return;
    }

    widget.onAdd(selectedVeg, price, qty);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedVeg,
              items: widget.vegetables
                  .map((veg) => DropdownMenuItem(value: veg, child: Text(veg)))
                  .toList(),
              onChanged: (val) => setState(() => selectedVeg = val!),
              decoration: const InputDecoration(
                labelText: 'Vegetable',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
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
              controller: qtyController,
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
          onPressed: _add,
          style: ElevatedButton.styleFrom(
            backgroundColor: FuturisticColors.primary,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EditItemDialog extends StatefulWidget {
  final BillItem item;
  final List<String> vegetables;
  final Function(String vegName, double pricePerKg, double qtyKg) onSave;

  const _EditItemDialog({
    required this.item,
    required this.vegetables,
    required this.onSave,
  });

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late String selectedVeg;
  late TextEditingController priceController;
  late TextEditingController qtyController;

  @override
  void initState() {
    super.initState();
    selectedVeg = widget.item.itemName;
    priceController = TextEditingController(
      text: widget.item.price.toStringAsFixed(0),
    );
    qtyController = TextEditingController(
      text: widget.item.qty.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    priceController.dispose();
    qtyController.dispose();
    super.dispose();
  }

  void _save() {
    final price = double.tryParse(priceController.text);
    final qty = double.tryParse(qtyController.text);

    if (price == null || qty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid price and quantity')),
      );
      return;
    }

    widget.onSave(selectedVeg, price, qty);
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
            DropdownButtonFormField<String>(
              value: selectedVeg,
              items: widget.vegetables
                  .map((veg) => DropdownMenuItem(value: veg, child: Text(veg)))
                  .toList(),
              onChanged: (val) => setState(() => selectedVeg = val!),
              decoration: const InputDecoration(
                labelText: 'Vegetable',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
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
              controller: qtyController,
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
            backgroundColor: FuturisticColors.primary,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
