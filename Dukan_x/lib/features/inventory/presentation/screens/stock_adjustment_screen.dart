import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/ui/futuristic_button.dart';
import '../../services/inventory_service.dart';
import '../../../../models/stock_item.dart';
import '../../../../screens/widgets/stock_product_picker.dart';
import 'package:intl/intl.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryService = sl<InventoryService>();
  final _userId =
      sl<SessionManager>().ownerId; // Assuming SessionManager available

  String _type = 'OUT'; // IN or OUT
  String _reason = 'DAMAGE';
  DateTime _date = DateTime.now();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  StockItem? _selectedProduct;
  bool _isLoading = false;

  final List<String> _reasonsOut = [
    'DAMAGE',
    'LOSS',
    'THEFT',
    'CONSUMPTION',
    'EXPIRED',
    'OTHER_OUT',
  ];

  final List<String> _reasonsIn = [
    'OPENING_STOCK',
    'PURCHASE_RETURN', // Wait, Purchase Return usually means OUT from us? Or Vendor Return?
    // Usually: Purchase Return = Stock OUT. Sale Return = Stock IN.
    // Let's correct this.
    // IN Reasons:
    'SALE_RETURN',
    'FOUND',
    'SURPLUS',
    'OTHER_IN',
  ];

  @override
  void initState() {
    super.initState();
    // Default reason
    _reason = _type == 'OUT' ? _reasonsOut.first : _reasonsIn.first;
  }

  void _onTypeChanged(String? val) {
    if (val != null) {
      setState(() {
        _type = val;
        _reason = val == 'OUT' ? _reasonsOut.first : _reasonsIn.first;
      });
    }
  }

  Future<void> _selectProduct() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StockProductPicker(ownerId: _userId ?? '', selectProductOnly: true),
    );

    if (result != null && result is StockItem) {
      setState(() {
        _selectedProduct = result;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a product')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final qty = double.parse(_quantityController.text);

      await _inventoryService.addStockMovement(
        userId: _userId ?? '',
        productId: _selectedProduct!.id,
        type: _type,
        reason: _reason,
        quantity: qty,
        referenceId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
        date: _date,
        description: _descriptionController.text.isEmpty
            ? 'Manual Adjustment ($_reason)'
            : _descriptionController.text,
        createdBy: sl<SessionManager>().currentSession.role.name.toUpperCase(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Adjusted Successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = _type == 'OUT' ? _reasonsOut : _reasonsIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Adjustment')),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Toggle
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'OUT', label: Text('Stock OUT (-)')),
                  ButtonSegment(value: 'IN', label: Text('Stock IN (+)')),
                ],
                selected: {_type},
                onSelectionChanged: (Set<String> newSelection) {
                  _onTypeChanged(newSelection.first);
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>((
                    states,
                  ) {
                    if (states.contains(MaterialState.selected)) {
                      return _type == 'OUT'
                          ? FuturisticColors.unpaidBackground
                          : FuturisticColors.paidBackground;
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Reason Dropdown
              DropdownButtonFormField<String>(
                value: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: reasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _reason = val!),
              ),
              const SizedBox(height: 16),

              // Product Selector
              InkWell(
                onTap: _selectProduct,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _selectedProduct?.name ?? 'Select Product',
                    style: TextStyle(
                      color: _selectedProduct == null
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
              ),
              if (_selectedProduct != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Current Stock: ${_selectedProduct!.quantity}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final v = double.tryParse(val);
                  if (v == null || v <= 0) return 'Invalid quantity';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Note (Optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Submit
              _type == 'OUT'
                  ? FuturisticButton.danger(
                      label: _isLoading ? 'Submitting...' : 'Submit Deduction',
                      icon: Icons.remove_circle,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _submit,
                    )
                  : FuturisticButton.success(
                      label: _isLoading ? 'Submitting...' : 'Submit Addition',
                      icon: Icons.add_circle,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _submit,
                    ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
