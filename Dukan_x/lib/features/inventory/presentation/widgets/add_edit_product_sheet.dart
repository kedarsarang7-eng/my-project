// ============================================================================
// ADD/EDIT PRODUCT SHEET - BUSINESS TYPE AWARE
// ============================================================================
// Dynamically renders product fields based on BusinessTypeConfig
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/billing/business_type_config.dart';
import '../../../../core/billing/feature_resolver.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/ui/futuristic_button.dart';

import 'forms/product_form_factory.dart';

class AddEditProductSheet extends StatefulWidget {
  final Product? product;
  const AddEditProductSheet({super.key, this.product});

  @override
  State<AddEditProductSheet> createState() => _AddEditProductSheetState();
}

class _AddEditProductSheetState extends State<AddEditProductSheet> {
  // Core fields (all businesses)
  late TextEditingController nameCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController stockCtrl;
  late TextEditingController unitCtrl;
  late TextEditingController taxRateCtrl;

  // Optional fields (business-specific)
  late TextEditingController sizeCtrl;
  late TextEditingController colorCtrl;
  late TextEditingController brandCtrl;
  late TextEditingController hsnCodeCtrl;
  late TextEditingController barcodeCtrl;
  late TextEditingController categoryCtrl;
  late TextEditingController drugScheduleCtrl; // New Control
  late TextEditingController skuController;

  bool _isSaving = false;
  BusinessType _businessType = BusinessType.grocery;
  BusinessTypeConfig? _config;

  // Factory & Data for Specialized Fields
  late ProductFormFactory _formFactory;
  Map<String, dynamic> _specializedData = {};

  // PHASE 2 FIX: SessionManager reference + listener handle so we rebuild
  // business-type-dependent config when the type changes while the sheet is
  // open. Previously this sheet cached `_businessType`/`_config`/`_formFactory`
  // once in initState and never refreshed them — so switching business type
  // with the sheet open showed stale fields/units/GST rate. See Phase 0 D.1.
  late final SessionManager _session;

  @override
  void initState() {
    super.initState();
    _initControllers();

    // Load Business Type from Single Source of Truth (SessionManager).
    // NOTE: SessionManager.activeBusinessType is kept in sync with the Riverpod
    // businessTypeProvider by the Phase 1 bridge (session_manager.setBusinessType),
    // so reading it here yields the current, persisted value.
    _session = sl<SessionManager>();
    _applyBusinessType(_session.activeBusinessType);

    // React to in-session business-type switches while the sheet is visible.
    _session.addListener(_onBusinessTypeChanged);
  }

  void _onBusinessTypeChanged() {
    final newType = _session.activeBusinessType;
    if (newType != _businessType) {
      // setState triggers rebuild; _applyBusinessType refreshes config/factory.
      setState(() {
        _applyBusinessType(newType);
      });
    }
  }

  /// Derives `_config` + `_formFactory` + default GST rate from [type].
  /// Centralised so both initState and the live-switch listener use it.
  void _applyBusinessType(BusinessType type) {
    _businessType = type;
    _config = BusinessTypeRegistry.getConfig(_businessType);
    _formFactory = ProductFormFactory.getFactory(_businessType);

    // Set default tax rate if empty
    if (taxRateCtrl.text.isEmpty && _config != null) {
      taxRateCtrl.text = _config!.defaultGstRate.toString();
    }
  }

  // (dispose is defined further below; the SessionManager listener is removed
  // there to avoid a duplicate dispose method.)

  void _initControllers() {
    final p = widget.product;
    nameCtrl = TextEditingController(text: p?.name ?? '');
    priceCtrl = TextEditingController(
      text: p?.sellingPrice != null ? p!.sellingPrice.toString() : '',
    );
    stockCtrl = TextEditingController(
      text: p?.stockQuantity != null ? p!.stockQuantity.toString() : '',
    );
    unitCtrl = TextEditingController(text: p?.unit ?? 'pcs');
    taxRateCtrl = TextEditingController(
      text: p?.taxRate != null ? p!.taxRate.toString() : '',
    );

    sizeCtrl = TextEditingController(text: p?.size ?? '');
    colorCtrl = TextEditingController(text: p?.color ?? '');
    brandCtrl = TextEditingController(text: p?.brand ?? '');
    hsnCodeCtrl = TextEditingController(text: p?.hsnCode ?? '');
    barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    categoryCtrl = TextEditingController(text: p?.category ?? '');
    drugScheduleCtrl = TextEditingController(text: p?.drugSchedule ?? '');
    skuController = TextEditingController(text: p?.sku ?? '');
  }

  bool _hasField(ItemField field) {
    return _config?.hasField(field) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config =
        _config ?? BusinessTypeRegistry.getConfig(BusinessType.grocery);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with business type indicator
            Row(
              children: [
                Text(
                  widget.product == null
                      ? 'Add New ${config.itemLabel}'
                      : 'Edit ${config.itemLabel}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _businessType.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_businessType.emoji} ${_businessType.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _businessType.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // CORE FIELDS (Always shown)
            _field('${config.itemLabel} Name *', nameCtrl, isDark),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    '${config.priceLabel} (₹) *',
                    priceCtrl,
                    isDark,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    'Stock Qty *',
                    stockCtrl,
                    isDark,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // UNIT SELECTOR
            if (_hasField(ItemField.unit)) ...[
              _unitDropdown(isDark, config),
              const SizedBox(height: 12),
            ],

            // TAX RATE (GST)
            if (FeatureResolver(_businessType).showProductTax) ...[
              if (config.gstEditable) ...[
                _field(
                  'Tax Rate (%)',
                  taxRateCtrl,
                  isDark,
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ] else ...[
                _readOnlyField(
                  'Tax Rate',
                  '${config.defaultGstRate}% (Fixed)',
                  isDark,
                ),
                const SizedBox(height: 12),
              ],
            ],

            // CLOTHING FIELDS
            if (_hasField(ItemField.size) || _hasField(ItemField.color)) ...[
              Row(
                children: [
                  if (_hasField(ItemField.size))
                    Expanded(child: _field('Size', sizeCtrl, isDark)),
                  if (_hasField(ItemField.size) && _hasField(ItemField.color))
                    const SizedBox(width: 12),
                  if (_hasField(ItemField.color))
                    Expanded(child: _field('Color', colorCtrl, isDark)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // BRAND (Driven by Config)
            if (_hasField(ItemField.brand)) ...[
              _field('Brand', brandCtrl, isDark),
              const SizedBox(height: 12),
            ],

            // HSN CODE (Electronics, Hardware, Pharmacy)
            if (_hasField(ItemField.hsnCode)) ...[
              _field('HSN Code', hsnCodeCtrl, isDark),
              const SizedBox(height: 12),
            ],

            // DRUG SCHEDULE (Driven by Config)
            if (_hasField(ItemField.drugSchedule)) ...[
              _field('Drug Schedule (H, H1, X)', drugScheduleCtrl, isDark),
              const SizedBox(height: 12),
            ],

            // BARCODE / SKU (useful for inventory management)
            Row(
              children: [
                Expanded(
                  child: _field('SKU (Optional)', skuController, isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('Barcode (Optional)', barcodeCtrl, isDark),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // FACTORY FIELDS (Batches, IMEIs, etc.)
            _formFactory.buildFields(
              context: context,
              product: widget.product,
              onDataChanged: (data) {
                _specializedData = data;
              },
            ),
            const SizedBox(height: 12),

            // CATEGORY
            _field('Category (Optional)', categoryCtrl, isDark),
            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FuturisticButton.success(
                label: _isSaving ? 'Saving...' : 'Save ${config.itemLabel}',
                icon: Icons.save,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _readOnlyField(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _unitDropdown(bool isDark, BusinessTypeConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Unit', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value:
                  config.unitOptions
                      .map((u) => u.label.toLowerCase())
                      .contains(unitCtrl.text.toLowerCase())
                  ? unitCtrl.text.toLowerCase()
                  : config.unitOptions.first.label.toLowerCase(),
              items: config.unitOptions
                  .map(
                    (unit) => DropdownMenuItem(
                      value: unit.label.toLowerCase(),
                      child: Text(unit.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => unitCtrl.text = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    // Validate required fields
    if (nameCtrl.text.isEmpty) {
      _showError('${_config?.itemLabel ?? 'Product'} name is required');
      return;
    }
    if (priceCtrl.text.isEmpty) {
      _showError('Price is required');
      return;
    }

    // Factory Validation
    final factoryError = _formFactory.validate(_specializedData);
    if (factoryError != null) {
      _showError(factoryError);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) {
        _showError('User session not found');
        return;
      }

      if (widget.product == null) {
        await sl<ProductsRepository>().createProduct(
          userId: userId,
          name: nameCtrl.text.trim(),
          sellingPrice: double.tryParse(priceCtrl.text) ?? 0,
          stockQuantity: double.tryParse(stockCtrl.text) ?? 0,
          unit: unitCtrl.text.trim(),
          taxRate:
              double.tryParse(taxRateCtrl.text) ?? _config?.defaultGstRate ?? 0,
          size: sizeCtrl.text.trim().isNotEmpty ? sizeCtrl.text.trim() : null,
          color: colorCtrl.text.trim().isNotEmpty
              ? colorCtrl.text.trim()
              : null,
          brand: brandCtrl.text.trim().isNotEmpty
              ? brandCtrl.text.trim()
              : null,
          hsnCode: hsnCodeCtrl.text.trim().isNotEmpty
              ? hsnCodeCtrl.text.trim()
              : null,
          sku: skuController.text.trim().isNotEmpty
              ? skuController.text.trim()
              : null,
          barcode: barcodeCtrl.text.trim().isNotEmpty
              ? barcodeCtrl.text.trim()
              : null,
          category: categoryCtrl.text.trim().isNotEmpty
              ? categoryCtrl.text.trim()
              : null,
          drugSchedule: drugScheduleCtrl.text.trim().isNotEmpty
              ? drugScheduleCtrl.text.trim()
              : null,
          // Phase 3: Extra Data
          initialBatches: _getBatches(),
          initialImeis: _getImeis(),
        );
      } else {
        final updated = widget.product!.copyWith(
          name: nameCtrl.text.trim(),
          sellingPrice: double.tryParse(priceCtrl.text) ?? 0,
          stockQuantity: double.tryParse(stockCtrl.text) ?? 0,
          unit: unitCtrl.text.trim(),
          taxRate:
              double.tryParse(taxRateCtrl.text) ?? _config?.defaultGstRate ?? 0,
          size: sizeCtrl.text.trim().isNotEmpty ? sizeCtrl.text.trim() : null,
          color: colorCtrl.text.trim().isNotEmpty
              ? colorCtrl.text.trim()
              : null,
          brand: brandCtrl.text.trim().isNotEmpty
              ? brandCtrl.text.trim()
              : null,
          hsnCode: hsnCodeCtrl.text.trim().isNotEmpty
              ? hsnCodeCtrl.text.trim()
              : null,
          sku: skuController.text.trim().isNotEmpty
              ? skuController.text.trim()
              : null,
          barcode: barcodeCtrl.text.trim().isNotEmpty
              ? barcodeCtrl.text.trim()
              : null,
          category: categoryCtrl.text.trim().isNotEmpty
              ? categoryCtrl.text.trim()
              : null,
          drugSchedule: drugScheduleCtrl.text.trim().isNotEmpty
              ? drugScheduleCtrl.text.trim()
              : null,
        );
        await sl<ProductsRepository>().updateProduct(updated, userId: userId);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: FuturisticColors.error),
    );
  }

  @override
  void dispose() {
    // PHASE 2 FIX: remove the SessionManager listener to avoid dangling callbacks.
    _session.removeListener(_onBusinessTypeChanged);
    nameCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
    unitCtrl.dispose();
    taxRateCtrl.dispose();
    sizeCtrl.dispose();
    colorCtrl.dispose();
    brandCtrl.dispose();
    hsnCodeCtrl.dispose();
    skuController.dispose();
    barcodeCtrl.dispose();
    categoryCtrl.dispose();
    drugScheduleCtrl.dispose();
    super.dispose();
  }

  // Helpers to extract specific data types
  List<Map<String, dynamic>>? _getBatches() {
    final saveData = _formFactory.prepareSaveData(_specializedData);
    if (saveData['type'] == 'BATCH') {
      return [
        {
          'batchNumber': saveData['batchNumber'],
          'expiryDate': saveData['expiryDate'],
          'mrp': saveData['mrp'],
          'purchaseRate': saveData['purchaseRate'],
          'quantity':
              double.tryParse(stockCtrl.text) ??
              0, // Initial batch gets full stock
        },
      ];
    }
    return null;
  }

  List<String>? _getImeis() {
    final saveData = _formFactory.prepareSaveData(_specializedData);
    if (saveData['type'] == 'IMEI') {
      return saveData['imeis'] as List<String>?;
    }
    return null;
  }
}
