// ============================================================================
// Computer Shop — Job Card Dialogs
// ============================================================================
// Dialogs for:
// - Adding parts to job
// - Assigning technician
// - Updating labor costs
// - Converting job to invoice
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/computer_repository.dart';
import 'product_search_bottom_sheet.dart';

// ============================================================================
// Add Part Bottom Sheet
// ============================================================================

class AddPartBottomSheet extends StatefulWidget {
  final String jobId;
  final Function(
    String productId,
    double quantity,
    double unitPrice,
    String? notes,
  )
  onAdd;

  const AddPartBottomSheet({
    super.key,
    required this.jobId,
    required this.onAdd,
  });

  @override
  State<AddPartBottomSheet> createState() => _AddPartBottomSheetState();
}

class _AddPartBottomSheetState extends State<AddPartBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  // Picker state for product selection (Req 22.1, 22.2, 22.3).
  String? _selectedProductId;
  String? _selectedProductLabel;

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openProductPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => ProductSearchBottomSheet(
          jobId: widget.jobId,
          onProductSelected: (productId, productName, unitPrice, quantity) {
            setState(() {
              _selectedProductId = productId;
              _selectedProductLabel = productName;
              _unitPriceController.text = unitPrice.toStringAsFixed(2);
              _quantityController.text = quantity.toString();
            });
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product using the picker'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onAdd(
        _selectedProductId!,
        double.parse(_quantityController.text),
        double.parse(
          _unitPriceController.text,
        ), // Rupees — conversion to paise happens at the repository boundary
        _notesController.text.isEmpty ? null : _notesController.text,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                const Text(
                  'Add Part to Job',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will deduct the part from inventory',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                // Product — Picker (Req 22.1, 22.2, 22.3)
                _DialogPickerTile(
                  label: 'Product *',
                  icon: Icons.inventory_2,
                  selectedLabel: _selectedProductLabel,
                  placeholder: 'Select Product',
                  onTap: _openProductPicker,
                ),
                const SizedBox(height: 16),
                // Quantity and Price Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity *',
                          prefixIcon: const Icon(Icons.format_list_numbered),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Unit Price (₹) *',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g., RAM upgrade, SSD replacement',
                    prefixIcon: const Icon(Icons.note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Submit Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Add Part',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Assign Technician Dialog
// ============================================================================

class AssignTechnicianDialog extends StatefulWidget {
  final Function(String techId, String techName) onAssign;

  const AssignTechnicianDialog({super.key, required this.onAssign});

  @override
  State<AssignTechnicianDialog> createState() => _AssignTechnicianDialogState();
}

class _AssignTechnicianDialogState extends State<AssignTechnicianDialog> {
  final _techIdController = TextEditingController();
  final _techNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_techIdController.text.isEmpty || _techNameController.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.onAssign(
        _techIdController.text.trim(),
        _techNameController.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('Assign Technician'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _techIdController,
            decoration: InputDecoration(
              labelText: 'Technician ID',
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _techNameController,
            decoration: InputDecoration(
              labelText: 'Technician Name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}

// ============================================================================
// Update Labor Dialog
// ============================================================================

class UpdateLaborDialog extends StatefulWidget {
  final double? estimatedLaborCost;
  final double? actualLaborCost;
  final String? diagnosis;
  final Function(double? estimated, double? actual, String? diagnosis) onUpdate;

  const UpdateLaborDialog({
    super.key,
    this.estimatedLaborCost,
    this.actualLaborCost,
    this.diagnosis,
    required this.onUpdate,
  });

  @override
  State<UpdateLaborDialog> createState() => _UpdateLaborDialogState();
}

class _UpdateLaborDialogState extends State<UpdateLaborDialog> {
  late final TextEditingController _estimatedController;
  late final TextEditingController _actualController;
  late final TextEditingController _diagnosisController;
  bool _isLoading = false;

  _UpdateLaborDialogState() {
    _estimatedController = TextEditingController(
      text: widget.estimatedLaborCost != null
          ? widget.estimatedLaborCost!.toStringAsFixed(2)
          : '',
    );
    _actualController = TextEditingController(
      text: widget.actualLaborCost != null
          ? widget.actualLaborCost!.toStringAsFixed(2)
          : '',
    );
    _diagnosisController = TextEditingController(text: widget.diagnosis ?? '');
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    final estimated = _estimatedController.text.isEmpty
        ? null
        : double.parse(
            _estimatedController.text,
          ); // Rupees — conversion to paise happens at the repository boundary
    final actual = _actualController.text.isEmpty
        ? null
        : double.parse(
            _actualController.text,
          ); // Rupees — conversion to paise happens at the repository boundary
    final diagnosis = _diagnosisController.text.isEmpty
        ? null
        : _diagnosisController.text;

    try {
      await widget.onUpdate(estimated, actual, diagnosis);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.attach_money, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('Update Labor Costs'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Estimated Labor
            TextField(
              controller: _estimatedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Estimated Labor (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'e.g., 500.00',
              ),
            ),
            const SizedBox(height: 16),
            // Actual Labor
            TextField(
              controller: _actualController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Actual Labor (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'e.g., 600.00',
              ),
            ),
            const SizedBox(height: 16),
            // Diagnosis
            TextField(
              controller: _diagnosisController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Diagnosis / Notes',
                prefixIcon: const Icon(Icons.medical_services),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Describe the problem and repair work done',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

// ============================================================================
// Convert to Invoice Dialog
// ============================================================================

class ConvertToInvoiceDialog extends StatefulWidget {
  final ComputerJobCard job;
  final Function(
    String customerName,
    String? customerPhone,
    String paymentMode,
    double discount,
  )
  onConvert;

  const ConvertToInvoiceDialog({
    super.key,
    required this.job,
    required this.onConvert,
  });

  @override
  State<ConvertToInvoiceDialog> createState() => _ConvertToInvoiceDialogState();
}

class _ConvertToInvoiceDialogState extends State<ConvertToInvoiceDialog> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  String _paymentMode = 'cash';
  bool _isLoading = false;

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  double get _laborCost =>
      widget.job.actualLaborCost ?? widget.job.estimatedLaborCost ?? 0;
  double get _partsCost => widget.job.actualPartsCost ?? 0;
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _total => _laborCost + _partsCost - _discount;

  Future<void> _submit() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.onConvert(
        _customerNameController.text.trim(),
        _customerPhoneController.text.isEmpty
            ? null
            : _customerPhoneController.text.trim(),
        _paymentMode,
        _discount, // Rupees — conversion to paise happens at the repository boundary
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.receipt_long, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('Convert to Invoice'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Labor Cost:'),
                      Text(currencyFormat.format(_laborCost)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Parts Cost:'),
                      Text(currencyFormat.format(_partsCost)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Total:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currencyFormat.format(_total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Customer Name
            TextField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: 'Customer Name *',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Customer Phone
            TextField(
              controller: _customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone (Optional)',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Payment Mode
            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: InputDecoration(
                labelText: 'Payment Mode',
                prefixIcon: const Icon(Icons.payment),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'credit', child: Text('Credit')),
              ],
              onChanged: (value) => setState(() => _paymentMode = value!),
            ),
            const SizedBox(height: 12),
            // Discount
            TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Discount (₹)',
                prefixIcon: const Icon(Icons.local_offer),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.receipt),
          label: Text(_isLoading ? 'Converting...' : 'Convert'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Shared Picker Tile Widget (Dialogs)
// ============================================================================

/// A tappable tile that displays a selected item label or a placeholder,
/// styled to match the form field appearance. Used to replace raw UUID text
/// fields with picker-based selection (Req 22.2).
class _DialogPickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? selectedLabel;
  final String placeholder;
  final VoidCallback onTap;

  const _DialogPickerTile({
    required this.label,
    required this.icon,
    required this.selectedLabel,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedLabel != null && selectedLabel!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          hasSelection ? selectedLabel! : placeholder,
          style: TextStyle(
            fontSize: 16,
            color: hasSelection
                ? const Color(0xFF1E293B)
                : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
