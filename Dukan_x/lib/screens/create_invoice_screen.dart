import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:uuid/uuid.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';

/// Create Invoice Screen - Form to create new invoices
/// Supports adding items, calculating totals, and saving

class CreateInvoiceScreen extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;

  const CreateInvoiceScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
  });

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  // Repository is lazy loaded via sl

  late TextEditingController _ownerNameController;
  late TextEditingController _ownerPhoneController;
  late TextEditingController _ownerAddressController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerAddressController;
  late TextEditingController _discountController;
  late TextEditingController _taxController;
  late TextEditingController _notesController;

  final List<BillItem> _items = []; // Use BillItem directly
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Repositories are injected via ServiceLocator (sl)

    _ownerNameController = TextEditingController();
    _ownerPhoneController = TextEditingController();
    _ownerAddressController = TextEditingController();
    _customerNameController = TextEditingController(
      text: widget.customerName ?? '',
    );
    _customerPhoneController = TextEditingController(
      text: widget.customerPhone ?? '',
    );
    _customerAddressController = TextEditingController(
      text: widget.customerAddress ?? '',
    );
    _discountController = TextEditingController(text: '0');
    _taxController = TextEditingController(text: '0');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _ownerAddressController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Owner Details'),
        _buildTextField(_ownerNameController, 'Owner Name', Icons.person),
        const SizedBox(height: 12),
        _buildTextField(_ownerPhoneController, 'Phone', Icons.phone),
        const SizedBox(height: 12),
        _buildTextField(
          _ownerAddressController,
          'Address',
          Icons.location_on,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Customer Details'),
        _buildTextField(
          _customerNameController,
          'Customer Name',
          Icons.person,
        ),
        const SizedBox(height: 12),
        _buildTextField(_customerPhoneController, 'Phone', Icons.phone),
        const SizedBox(height: 12),
        _buildTextField(
          _customerAddressController,
          'Address',
          Icons.location_on,
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Items'),
        _buildItemsList(),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Charges'),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _discountController,
                'Discount (₹)',
                Icons.discount,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                _taxController,
                'Tax (₹)',
                Icons.receipt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTotalsSummary(),
        const SizedBox(height: 24),
        _buildSectionTitle('Notes'),
        _buildTextField(_notesController, 'Notes', Icons.note),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveInvoice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'Save Invoice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Create Invoice'), elevation: 0),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftColumn,
                    const SizedBox(height: 24),
                    rightColumn,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: leftColumn),
                    const SizedBox(width: 32),
                    Expanded(flex: 6, child: rightColumn),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: TextInputType.text,
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            'No items added yet',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(
        _items.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildItemCard(_items[index], index),
        ),
      ),
    );
  }

  Widget _buildItemCard(BillItem item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Qty: ${item.qty} × ₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          IconButton(
            onPressed: () => setState(() => _items.removeAt(index)),
            icon: const Icon(Icons.delete, color: Colors.red),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSummary() {
    // Calculate totals locally
    double subtotal = 0;
    for (var item in _items) {
      subtotal += item.total;
    }

    final discount = double.tryParse(_discountController.text) ?? 0;
    final tax = double.tryParse(_taxController.text) ?? 0;
    final total = (subtotal - discount) + tax;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', subtotal),
          if (discount > 0)
            _buildTotalRow('Discount', -discount, isNegative: true),
          if (tax > 0) _buildTotalRow('Tax', tax),
          const Divider(height: 16),
          _buildTotalRow('Total', total, isBold: true, isLarge: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isLarge = false,
    bool isNegative = false,
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
              fontSize: isLarge ? 16 : 14,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}₹${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isLarge ? 16 : 14,
              color: isLarge ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        onSave: (name, quantity, price) {
          setState(() {
            _items.add(
              BillItem(
                productId: '', // Ad-hoc item
                productName: name,
                qty: quantity,
                price: price,
              ),
            );
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveInvoice() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      double subtotal = 0;
      for (var item in _items) {
        subtotal += item.total;
      }

      final discount = double.tryParse(_discountController.text) ?? 0;
      final tax = double.tryParse(_taxController.text) ?? 0;
      final total = (subtotal - discount) + tax;

      final ownerId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final bill = Bill(
        id: const Uuid().v4(), // Generate ID
        ownerId: ownerId,
        invoiceNumber:
            'INV-${DateTime.now().millisecondsSinceEpoch}', // Simple auto-gen
        customerId: widget.customerId ?? '',
        customerName: _customerNameController.text.isNotEmpty
            ? _customerNameController.text
            : (widget.customerName ?? 'Walk-in Customer'),
        customerPhone: _customerPhoneController.text,
        customerAddress: _customerAddressController.text,
        shopName:
            _ownerNameController.text, // Using owner name as shop name for now
        shopContact: _ownerPhoneController.text,
        shopAddress: _ownerAddressController.text,
        date: DateTime.now(),
        items: _items,
        subtotal: subtotal,
        discountApplied: discount,
        totalTax: tax,
        grandTotal: total,
        status: 'Unpaid',
        paymentType: 'Cash',
        // Notes handled at BillItem level, not Bill level
      );

      await sl<BillsRepository>().createBill(bill);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Dialog to add invoice items
class _ItemDialog extends StatefulWidget {
  final Function(String name, double quantity, double price) onSave;

  const _ItemDialog({required this.onSave});

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _priceController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: Column(
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
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Price per Unit',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final quantity = double.tryParse(_quantityController.text) ?? 1;
            final price = double.tryParse(_priceController.text) ?? 0;

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter item name')),
              );
              return;
            }

            widget.onSave(name, quantity, price);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
