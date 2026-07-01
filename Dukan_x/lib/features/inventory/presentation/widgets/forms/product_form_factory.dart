import 'package:flutter/material.dart';
import '../../../../../models/business_type.dart';

/// Abstract Factory for Business-Specific Product Forms
abstract class ProductFormFactory {
  /// Returns the specific factory based on business type
  static ProductFormFactory getFactory(BusinessType type) {
    switch (type) {
      case BusinessType.pharmacy:
      case BusinessType.wholesale: // Wholesale often needs batch/expiry too
        return PharmacyFormFactory();
      case BusinessType.electronics:
      case BusinessType.mobileShop:
        return ElectronicsFormFactory();
      case BusinessType.service:
        return ServiceFormFactory();
      case BusinessType.grocery:
      default:
        return GroceryFormFactory();
    }
  }

  /// Builds the specialized form fields for this business type
  Widget buildFields({
    required BuildContext context,
    dynamic product,
    required Function(Map<String, dynamic> data) onDataChanged,
  });

  /// Validates the specialized data
  String? validate(Map<String, dynamic> data);

  /// Prepares the DTO for persistence (handled by Repository)
  /// Returns a Map that determines what extra entities to create
  Map<String, dynamic> prepareSaveData(Map<String, dynamic> formUiData);
}

// ============================================================================
// CONCRETE FACTORIES
// ============================================================================

/// 1. GROCERY / RETAIL (Standard)
class GroceryFormFactory extends ProductFormFactory {
  @override
  Widget buildFields({
    required BuildContext context,
    dynamic product,
    required Function(Map<String, dynamic> data) onDataChanged,
  }) {
    // No extra fields for standard grocery yet (maybe Brand later)
    return const SizedBox.shrink();
  }

  @override
  String? validate(Map<String, dynamic> data) => null;

  @override
  Map<String, dynamic> prepareSaveData(Map<String, dynamic> formUiData) => {};
}

/// 2. PHARMACY (Batch & Expiry)
class PharmacyFormFactory extends ProductFormFactory {
  @override
  Widget buildFields({
    required BuildContext context,
    dynamic product,
    required Function(Map<String, dynamic> data) onDataChanged,
  }) {
    // We will implement the actual widget in a separate file to keep this clean
    // For now, returning a placeholder callback mechanism
    return _PharmacyFields(initialProduct: product, onChanged: onDataChanged);
  }

  @override
  String? validate(Map<String, dynamic> data) {
    if (data['batchNumber'] == null || data['batchNumber'].toString().isEmpty) {
      return 'Batch Number is required for Pharmacy items';
    }
    if (data['expiryDate'] == null) {
      return 'Expiry Date is required';
    }
    return null;
  }

  @override
  Map<String, dynamic> prepareSaveData(Map<String, dynamic> formUiData) {
    return {
      'type': 'BATCH',
      'batchNumber': formUiData['batchNumber'],
      'expiryDate': formUiData['expiryDate'],
      'mrp': formUiData['mrp'], // Batch specific MRP
      'purchaseRate': formUiData['purchaseRate'], // Batch specific PTR
    };
  }
}

/// 3. ELECTRONICS (IMEI / Serial)
class ElectronicsFormFactory extends ProductFormFactory {
  @override
  Widget buildFields({
    required BuildContext context,
    dynamic product,
    required Function(Map<String, dynamic> data) onDataChanged,
  }) {
    return _ElectronicsFields(
      initialProduct: product,
      onChanged: onDataChanged,
    );
  }

  @override
  String? validate(Map<String, dynamic> data) {
    // If tracking is enabled implementation
    final imeis = data['imeis'] as List<String>?;
    if (imeis != null && imeis.isNotEmpty) {
      // Basic validation if needed
    }
    return null;
  }

  @override
  Map<String, dynamic> prepareSaveData(Map<String, dynamic> formUiData) {
    return {
      'type': 'IMEI',
      'imeis': formUiData['imeis'], // List of IMEIs to add
      'warrantyMonths': formUiData['warrantyMonths'],
    };
  }
}

/// 4. SERVICE (Consultation / Repair)
class ServiceFormFactory extends ProductFormFactory {
  @override
  Widget buildFields({
    required BuildContext context,
    dynamic product,
    required Function(Map<String, dynamic> data) onDataChanged,
  }) {
    return _ServiceFields(initialProduct: product, onChanged: onDataChanged);
  }

  @override
  String? validate(Map<String, dynamic> data) => null;

  @override
  Map<String, dynamic> prepareSaveData(Map<String, dynamic> formUiData) {
    return {
      'type': 'SERVICE',
      'isService': true,
      // Service specific fields (e.g. time duration)
    };
  }
}

// ============================================================================
// INTERNAL WIDGETS (Placeholders for now, will expand)
// ============================================================================

class _PharmacyFields extends StatefulWidget {
  final dynamic initialProduct;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _PharmacyFields({this.initialProduct, required this.onChanged});

  @override
  State<_PharmacyFields> createState() => _PharmacyFieldsState();
}

class _PharmacyFieldsState extends State<_PharmacyFields> {
  final _batchCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    // Hook up listeners
    _batchCtrl.addListener(_notify);
    _mrpCtrl.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'batchNumber': _batchCtrl.text,
      'mrp': double.tryParse(_mrpCtrl.text),
      'expiryDate': _expiryDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Pharmacy Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _batchCtrl,
          decoration: const InputDecoration(
            labelText: 'Batch Number *',
            border: OutlineInputBorder(),
            filled: true,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (date != null) {
              setState(() => _expiryDate = date);
              _notify();
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Expiry Date *',
              border: OutlineInputBorder(),
              filled: true,
            ),
            child: Text(
              _expiryDate == null
                  ? 'Select Date'
                  : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
            ),
          ),
        ),
      ],
    );
  }
}

class _ElectronicsFields extends StatelessWidget {
  final dynamic initialProduct;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _ElectronicsFields({this.initialProduct, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Electronics Tracking',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (val) => onChanged({
            'imeis': [val],
          }), // Simplified for single add
          decoration: const InputDecoration(
            labelText: 'IMEI / Serial Number (Optional)',
            hintText: 'Scan or enter IMEI',
            border: OutlineInputBorder(),
            filled: true,
            suffixIcon: Icon(Icons.qr_code),
          ),
        ),
      ],
    );
  }
}

class _ServiceFields extends StatelessWidget {
  final dynamic initialProduct;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _ServiceFields({this.initialProduct, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Placeholder
  }
}
