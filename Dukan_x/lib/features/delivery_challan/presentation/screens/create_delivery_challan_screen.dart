import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/repository/products_repository.dart';
import '../../models/delivery_challan_model.dart';
import '../../services/delivery_challan_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CreateDeliveryChallanScreen extends StatefulWidget {
  final DeliveryChallan? existingChallan;
  const CreateDeliveryChallanScreen({super.key, this.existingChallan});

  @override
  State<CreateDeliveryChallanScreen> createState() =>
      _CreateDeliveryChallanScreenState();
}

class _CreateDeliveryChallanScreenState
    extends State<CreateDeliveryChallanScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Fields - using domain models instead of entities
  Customer? _selectedCustomer;
  DateTime _challanDate = DateTime.now();
  final _vehicleController = TextEditingController();
  final _eWayBillController = TextEditingController();
  String _transportMode = 'Road';

  final List<DeliveryChallanItem> _items = [];
  bool _isLoading = false;

  // Cache for loaded data
  List<Customer> _customers = [];
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final session = sl<SessionManager>();
    final userId = session.ownerId ?? '';

    // Load customers and products
    final customersResult = await sl<CustomersRepository>().getAll(
      userId: userId,
    );
    final productsResult = await sl<ProductsRepository>().getAll(
      userId: userId,
    );

    setState(() {
      _customers = customersResult.data ?? [];
      _products = productsResult.data ?? [];
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _eWayBillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Delivery Challan')),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Customer Selection
                  _buildCustomerSelector(),
                  const SizedBox(height: 16),

                  // Date & Transport
                  _buildTransportSection(),
                  const SizedBox(height: 24),

                  // Items Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items',
                        style: TextStyle(
                          fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddItemDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Items List
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('No items added. Add items to proceed.'),
                      ),
                    )
                  else
                    ..._items.map((item) => _buildItemTile(item)),

                  const SizedBox(height: 32),

                  // Save Button
                  ElevatedButton(
                    onPressed: _items.isNotEmpty ? _saveChallan : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Create Challan'),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return DropdownButtonFormField<Customer>(
      value: _selectedCustomer,
      decoration: const InputDecoration(
        labelText: 'Select Customer',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      items: _customers
          .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
          .toList(),
      onChanged: (val) => setState(() => _selectedCustomer = val),
      validator: (val) => val == null ? 'Required' : null,
    );
  }

  Widget _buildTransportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _challanDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _challanDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_challanDate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _transportMode,
                    decoration: const InputDecoration(
                      labelText: 'Transport Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Road', 'Rail', 'Air', 'Ship']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) => setState(() => _transportMode = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicleController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _eWayBillController,
              decoration: const InputDecoration(
                labelText: 'E-Way Bill Number (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(DeliveryChallanItem item) {
    return ListTile(
      title: Text(item.productName),
      subtitle: Text('${item.quantity} ${item.unit} x ₹${item.unitPrice}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '₹${item.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                _items.remove(item);
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    Product? selectedProduct;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  value: selectedProduct,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _products
                      .map(
                        (p) => DropdownMenuItem<Product>(
                          value: p,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedProduct = val;
                      priceController.text = val?.sellingPrice.toString() ?? '';
                    });
                  },
                ),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Unit Price'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedProduct != null &&
                      qtyController.text.isNotEmpty) {
                    final qty = double.tryParse(qtyController.text) ?? 1;
                    final price = double.tryParse(priceController.text) ?? 0;

                    // Calculate Tax
                    final taxRate = selectedProduct!.taxRate;
                    final baseAmount = qty * price;

                    // GST Logic (Simple Intra-state assumption)
                    final cgstRate = taxRate / 2;
                    final sgstRate = taxRate / 2;
                    final cgst = baseAmount * cgstRate / 100;
                    final sgst = baseAmount * sgstRate / 100;

                    final item = DeliveryChallanItem(
                      id: const Uuid().v4(),
                      productId: selectedProduct!.id,
                      productName: selectedProduct!.name,
                      quantity: qty,
                      unit: selectedProduct!.unit,
                      unitPrice: price,
                      taxRate: taxRate,
                      taxAmount: cgst + sgst,
                      totalAmount: baseAmount + cgst + sgst,
                      hsnCode: selectedProduct!.hsnCode,
                      cgstRate: cgstRate,
                      cgstAmount: cgst,
                      sgstRate: sgstRate,
                      sgstAmount: sgst,
                    );

                    setState(() {
                      _items.add(item);
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveChallan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) return;

    setState(() => _isLoading = true);

    final service = sl<DeliveryChallanService>();

    final challan = await service.createChallan(
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      items: _items,
      challanDate: _challanDate,
      transportMode: _transportMode,
      vehicleNumber: _vehicleController.text,
      eWayBillNumber: _eWayBillController.text,
    );

    setState(() => _isLoading = false);

    if (challan != null && mounted) {
      Navigator.pop(context); // Go back to list
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save challan')));
    }
  }
}
