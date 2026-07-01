// ============================================================================
// MANUAL ITEM ENTRY SHEET - BUSINESS AWARE & DYNAMIC
// ============================================================================
// Allows manual item entry with strict business-type validation
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/billing/business_type_config.dart'; // Grocery unitOptions (kg/gm) source of truth + BusinessType
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/session/session_manager.dart';
import '../../../service/data/repositories/imei_serial_repository.dart';
import '../../../service/models/imei_serial.dart';
import '../../../../models/bill.dart';
import '../../../../widgets/glass_bottom_sheet.dart';
import '../../../hardware/widgets/dimension_calculator.dart';
import '../../../../utils/unit_conversion_service.dart';

/// Manual Item Entry Sheet
///
/// Provides a form for entering items manually with dynamic fields
/// based on the selected Business Type.
class ManualItemEntrySheet extends StatefulWidget {
  final Function(BillItem) onItemAdded;
  final BusinessType businessType;
  final String? defaultUnit;
  final double? defaultGstRate;

  const ManualItemEntrySheet({
    super.key,
    required this.onItemAdded,
    required this.businessType,
    this.defaultUnit,
    this.defaultGstRate,
  });

  @override
  State<ManualItemEntrySheet> createState() => _ManualItemEntrySheetState();
}

class _ManualItemEntrySheetState extends State<ManualItemEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController();
  final _gstController = TextEditingController();
  final _hsnController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  // Business Specific Controllers
  final _batchController = TextEditingController(); // Pharmacy
  final _expiryController = TextEditingController(); // Pharmacy
  DateTime? _selectedExpiryDate;

  final _serialController = TextEditingController(); // Electronics
  final _warrantyController = TextEditingController(); // Electronics

  final _sizeController = TextEditingController(); // Clothing/Hardware
  final _colorController = TextEditingController(); // Clothing

  // Hardware: dimensions captured via the DimensionCalculator (2.12) and the
  // unit-conversion helper (2.13). Stored so they round-trip onto the BillItem.
  String? _hardwareDimensions;
  static const _unitConverter = UnitConversionService();

  String _selectedUnit = 'pcs';
  bool _isLoading = false;

  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'l',
    'ml',
    'box',
    'pack',
    'dozen',
    'meter',
    'sq.ft',
    'hour',
    'service',
  ];

  /// Unit choices for the dropdown.
  ///
  /// Grocery sources its options from the business config (`unitOptions`:
  /// pcs, kg, gm, ltr, nos) so loose-weight units like kg/gm are selectable
  /// (Req 7.4). Other business types keep the existing fixed list so their
  /// behavior is unchanged.
  List<String> get _unitChoices {
    if (widget.businessType == BusinessType.grocery) {
      final options = BusinessTypeRegistry.getConfig(
        widget.businessType,
      ).unitOptions.map((u) => u.label.toLowerCase()).toList();
      if (options.isNotEmpty) return options;
    }
    return _units;
  }

  @override
  void initState() {
    super.initState();
    // Default the unit from the grocery config (first option, pcs) so the
    // selected value is always a valid member of the dropdown choices.
    _selectedUnit = _unitChoices.first;
    if (widget.defaultUnit != null &&
        _unitChoices.contains(widget.defaultUnit)) {
      _selectedUnit = widget.defaultUnit!;
    }
    if (widget.defaultGstRate != null) {
      _gstController.text = widget.defaultGstRate!.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _gstController.dispose();
    _hsnController.dispose();
    _discountController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _serialController.dispose();
    _warrantyController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now, // Cannot sell expired items manually
      lastDate: now.add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
        _expiryController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final qty = double.tryParse(_qtyController.text) ?? 1;
      final rate = double.tryParse(_rateController.text) ?? 0;
      final gstRate = double.tryParse(_gstController.text) ?? 0;
      final discount = double.tryParse(_discountController.text) ?? 0;
      final hsn = _hsnController.text.trim();

      // Calculate GST amounts
      final taxableAmount = (qty * rate) - discount;
      final gstAmount = taxableAmount * (gstRate / 100);
      final cgst = gstAmount / 2;
      final sgst = gstAmount / 2;

      // Basic Item
      BillItem item = BillItem(
        productId: '', // Empty ID indicates manual entry
        productName: name,
        qty: qty,
        price: rate,
        unit: _selectedUnit,
        hsn: hsn,
        gstRate: gstRate,
        discount: discount,
        cgst: cgst,
        sgst: sgst,
      );

      // Inject Business Specific Data
      if (widget.businessType == BusinessType.pharmacy) {
        item = item.copyWith(
          batchNo: _batchController.text.trim(),
          expiryDate: _selectedExpiryDate,
        );
      } else if (widget.businessType == BusinessType.electronics ||
          widget.businessType == BusinessType.mobileShop ||
          widget.businessType == BusinessType.computerShop) {
        int? warranty;
        if (_warrantyController.text.isNotEmpty) {
          warranty = int.tryParse(_warrantyController.text);
        }
        item = item.copyWith(
          serialNo: _serialController.text.trim(),
          warrantyMonths: warranty,
        );
      } else if (widget.businessType == BusinessType.clothing) {
        item = item.copyWith(
          size: _sizeController.text.trim(),
          color: _colorController.text.trim(),
        );
      } else if (widget.businessType == BusinessType.hardware) {
        item = item.copyWith(
          size: _sizeController.text.trim(),
          dimensions: _hardwareDimensions ?? _sizeController.text.trim(),
        );
      }

      // Phase 2 (Req 5.3, 5.9): Reject duplicate IMEIs at the UI layer before
      // persistence. Only applies to mobileShop (business type contains 'mobile').
      if (widget.businessType.name.contains('mobile')) {
        final serialNo = item.serialNo ?? '';
        if (serialNo.isNotEmpty) {
          final userId = sl<SessionManager>().ownerId ?? '';
          if (userId.isNotEmpty) {
            final imeiRepo = IMEISerialRepository(sl<AppDatabase>());
            final existing = await imeiRepo.getByNumber(userId, serialNo);
            if (existing != null) {
              const conflictStatuses = {
                IMEISerialStatus.sold,
                IMEISerialStatus.inService,
                IMEISerialStatus.damaged,
                IMEISerialStatus.demo,
              };
              if (conflictStatuses.contains(existing.status)) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'IMEI $serialNo already has status '
                        "'${existing.status.displayName}' "
                        'and cannot be sold again.',
                      ),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                return; // Prevent adding the item to the bill
              }
            }
          }
        }
      }

      widget.onItemAdded(item);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassBottomSheet(
      title: 'Manual Item Entry',
      subtitle: widget.businessType.displayName,
      icon: Icons.edit_note,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Product/Service Name
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _buildInputDecoration(
                  'Item Name',
                  Icons.shopping_bag_outlined,
                  isDark,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // === DYNAMIC BUSINESS FIELDS START ===
              if (widget.businessType == BusinessType.pharmacy) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _batchController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: _buildInputDecoration(
                          'Batch No',
                          Icons.qr_code_2,
                          isDark,
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickExpiryDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _expiryController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: _buildInputDecoration(
                              'Expiry Date',
                              Icons.calendar_today,
                              isDark,
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (widget.businessType == BusinessType.electronics ||
                  widget.businessType == BusinessType.mobileShop ||
                  widget.businessType == BusinessType.computerShop) ...[
                TextFormField(
                  controller: _serialController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: _buildInputDecoration(
                    widget.businessType == BusinessType.mobileShop ||
                            widget.businessType == BusinessType.electronics
                        ? 'Serial No / IMEI *'
                        : 'Serial No / IMEI',
                    Icons.tag,
                    isDark,
                    hint: 'Scan or enter serial number',
                  ),
                  validator: widget.businessType == BusinessType.mobileShop
                      ? (v) => v == null || v.trim().isEmpty
                            ? 'IMEI / Serial No is required for mobile shop'
                            : null
                      : widget.businessType == BusinessType.electronics
                      ? (v) => v == null || v.trim().isEmpty
                            ? 'IMEI / Serial No is required for electronics'
                            : null
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _warrantyController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: _buildInputDecoration(
                    'Warranty (Months)',
                    Icons.verified_user_outlined,
                    isDark,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final parsed = int.tryParse(v.trim());
                    if (parsed == null) {
                      return 'Warranty must be a whole number';
                    }
                    if (parsed < 0 || parsed > 120) {
                      return 'Warranty must be between 0 and 120 months';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (widget.businessType == BusinessType.clothing) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sizeController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: _buildInputDecoration(
                          'Size',
                          Icons.straighten,
                          isDark,
                          hint: 'S, M, L, XL...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: _buildInputDecoration(
                          'Color',
                          Icons.palette_outlined,
                          isDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (widget.businessType == BusinessType.hardware) ...[
                TextFormField(
                  controller: _sizeController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: _buildInputDecoration(
                    'Size / Dimensions',
                    Icons.straighten,
                    isDark,
                  ),
                ),
                const SizedBox(height: 16),
                // Dimension calculator (bugfix.md 2.12): surfaces ft↔mtr
                // conversion, presets and area calculation in the live line-item
                // editor. On calculate it fills the dimensions field and sets the
                // quantity to the computed area so the line bills by area.
                DimensionCalculator(
                  initialDimensions: _hardwareDimensions,
                  onCalculate: (result) {
                    setState(() {
                      _hardwareDimensions = result.dimensionsOnly;
                      _sizeController.text = result.displayString;
                      _qtyController.text = result.area.toStringAsFixed(2);
                      final areaUnit = result.areaUnit == 'sqft'
                          ? 'sq.ft'
                          : 'meter';
                      if (_unitChoices.contains(areaUnit)) {
                        _selectedUnit = areaUnit;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Unit converter (bugfix.md 2.13): converts the entered quantity
                // between hardware units (ft↔mtr, box↔pcs) using the shared
                // UnitConversionService, writing the result back to the quantity.
                _HardwareUnitConverter(
                  isDark: isDark,
                  converter: _unitConverter,
                  currentQty: () => double.tryParse(_qtyController.text) ?? 0,
                  onConverted: (value, toUnit) {
                    setState(() {
                      _qtyController.text = value.toStringAsFixed(2);
                      if (_unitChoices.contains(toUnit)) {
                        _selectedUnit = toUnit;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              // === DYNAMIC BUSINESS FIELDS END ===

              // Quantity & Unit Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: _buildInputDecoration(
                        'Quantity',
                        Icons.numbers,
                        isDark,
                      ),
                      validator: (v) {
                        final qty = double.tryParse(v ?? '');
                        if (qty == null || qty <= 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      dropdownColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: _buildInputDecoration('Unit', null, isDark),
                      items: _unitChoices
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _selectedUnit = v ?? _unitChoices.first,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Rate
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _buildInputDecoration(
                  'Rate (₹)',
                  Icons.currency_rupee,
                  isDark,
                ),
                validator: (v) {
                  final rate = double.tryParse(v ?? '');
                  if (rate == null || rate < 0) return 'Invalid rate';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // GST % & Discount Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gstController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: _buildInputDecoration(
                        'GST %',
                        Icons.receipt_long_outlined,
                        isDark,
                        hint: 'Optional',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: _buildInputDecoration(
                        'Discount (₹)',
                        Icons.local_offer_outlined,
                        isDark,
                        hint: 'Optional',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // HSN Code (Optional)
              TextFormField(
                controller: _hsnController,
                keyboardType: TextInputType.text,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _buildInputDecoration(
                  'HSN Code',
                  Icons.qr_code,
                  isDark,
                  hint: 'Optional',
                ),
                validator: (value) {
                  // Phase 7, Task 23.4 / Req 2.25: HSN format validation.
                  if (value == null || value.trim().isEmpty) return null;
                  final trimmed = value.trim();
                  if (!RegExp(r'^\d{4}$|^\d{8}$').hasMatch(trimmed)) {
                    return 'HSN must be 4 or 8 digits (numeric only)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Live Preview
              _buildLivePreview(isDark),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: FuturisticColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: FuturisticColors.primary.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline),
                              SizedBox(width: 8),
                              Text(
                                'Add to Bill',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData? icon,
    bool isDark, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: FuturisticColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLivePreview(bool isDark) {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    final gstRate = double.tryParse(_gstController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;

    final subtotal = qty * rate;
    final afterDiscount = subtotal - discount;
    final gstAmount = afterDiscount * (gstRate / 100);
    final total = afterDiscount + gstAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? FuturisticColors.primary.withOpacity(0.1)
            : FuturisticColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FuturisticColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                '₹${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          if (discount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount',
                  style: TextStyle(
                    color: FuturisticColors.success,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '-₹${discount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: FuturisticColors.success,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          if (gstRate > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GST ($gstRate%)',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '+₹${gstAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: FuturisticColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact hardware unit converter (bugfix.md 2.13).
///
/// Lets the user convert the current line quantity between hardware units
/// (feet↔metre, box↔pieces) using the shared [UnitConversionService]. For the
/// box↔pcs conversion the user supplies a pieces-per-box pack size. The
/// converted value is written back to the quantity field via [onConverted].
class _HardwareUnitConverter extends StatefulWidget {
  const _HardwareUnitConverter({
    required this.isDark,
    required this.converter,
    required this.currentQty,
    required this.onConverted,
  });

  final bool isDark;
  final UnitConversionService converter;
  final double Function() currentQty;
  final void Function(double value, String toUnit) onConverted;

  @override
  State<_HardwareUnitConverter> createState() => _HardwareUnitConverterState();
}

class _HardwareUnitConverterState extends State<_HardwareUnitConverter> {
  static const _units = <String>['ft', 'mtr', 'box', 'pcs'];
  String _from = 'ft';
  String _to = 'mtr';
  final _packController = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _packController.dispose();
    super.dispose();
  }

  bool get _needsPack =>
      (_from == 'box' && _to == 'pcs') || (_from == 'pcs' && _to == 'box');

  void _convert() {
    final qty = widget.currentQty();
    final pack = int.tryParse(_packController.text);
    if (!widget.converter.canConvert(_from, _to, piecesPerBox: pack)) {
      setState(() => _error = 'Cannot convert $_from → $_to');
      return;
    }
    try {
      final result = widget.converter.convert(
        qty,
        _from,
        _to,
        piecesPerBox: pack,
      );
      setState(() => _error = null);
      // Map the conversion target onto a bill unit label where one exists; an
      // empty string leaves the selected unit unchanged.
      final toUnit = _to == 'mtr'
          ? 'meter'
          : (_to == 'box' || _to == 'pcs')
          ? _to
          : '';
      widget.onConverted(result, toUnit);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString() ?? 'Conversion failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Unit Converter',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _from,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _from = v ?? 'ft'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _to,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _to = v ?? 'mtr'),
                ),
              ),
            ],
          ),
          if (_needsPack) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _packController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pieces per box',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _convert,
              icon: const Icon(Icons.calculate, size: 16),
              label: const Text('Convert quantity'),
            ),
          ),
        ],
      ),
    );
  }
}
