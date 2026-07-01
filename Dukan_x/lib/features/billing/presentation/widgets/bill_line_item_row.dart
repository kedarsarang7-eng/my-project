// ============================================================================
// BILL LINE ITEM ROW WIDGET
// ============================================================================
// Inline-editable table row matching the reference UI.
// All edits are reflected immediately via onUpdate callback.
// Business-type extra columns are driven by BillFieldConfig.
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter/services.dart';
import '../../../../models/bill.dart';
import '../../../../core/billing/business_type_config.dart';
import '../../../jewellery/utils/jewellery_business_rules.dart';
import 'bill_creation_tokens.dart';
import 'product_avatar.dart';

class BillFieldConfig {
  final bool showBatchNo;
  final bool showExpiryDate;
  final bool showSerialNo;

  /// Whether the serial/IMEI field is required (not just present).
  /// Driven by `config.isRequired(ItemField.serialNo)` — true for mobileShop.
  final bool serialNoRequired;
  final bool showPurity;
  final bool showWeight;
  final bool showMakingCharges;
  final bool showIsbn;
  final bool showVehicleModel;
  final bool showTableNo;
  final bool showNozzleId;
  final bool showCommission;

  const BillFieldConfig({
    this.showBatchNo = false,
    this.showExpiryDate = false,
    this.showSerialNo = false,
    this.serialNoRequired = false,
    this.showPurity = false,
    this.showWeight = false,
    this.showMakingCharges = false,
    this.showIsbn = false,
    this.showVehicleModel = false,
    this.showTableNo = false,
    this.showNozzleId = false,
    this.showCommission = false,
  });

  factory BillFieldConfig.fromBusinessType(BusinessType type) {
    final config = BusinessTypeRegistry.getConfig(type);
    return BillFieldConfig(
      showBatchNo: config.hasField(ItemField.batchNo),
      showExpiryDate: config.hasField(ItemField.expiryDate),
      showSerialNo: config.hasField(ItemField.serialNo),
      serialNoRequired: config.isRequired(ItemField.serialNo),
      showPurity: config.hasField(ItemField.purity),
      showWeight: config.hasField(ItemField.metalWeight),
      showMakingCharges: config.hasField(ItemField.makingCharges),
      showIsbn: config.hasField(ItemField.isbn),
      showVehicleModel: config.hasField(ItemField.vehicleModel),
      showTableNo: config.hasField(ItemField.tableNo),
      showNozzleId: config.hasField(ItemField.nozzleId),
      showCommission: config.hasField(ItemField.commission),
    );
  }
}

class BillLineItemRow extends StatefulWidget {
  final int serialNumber;
  final BillItem item;
  final BillFieldConfig fieldConfig;
  final List<String> unitOptions;
  final ValueChanged<BillItem> onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const BillLineItemRow({
    super.key,
    required this.serialNumber,
    required this.item,
    required this.fieldConfig,
    required this.unitOptions,
    required this.onUpdate,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<BillLineItemRow> createState() => _BillLineItemRowState();
}

class _BillLineItemRowState extends State<BillLineItemRow> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _makingChargesCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.item.qty == widget.item.qty.roundToDouble()
          ? widget.item.qty.toInt().toString()
          : widget.item.qty.toString(),
    );
    _priceCtrl = TextEditingController(
      text: widget.item.price.toStringAsFixed(2),
    );
    _discCtrl = TextEditingController(
      text: widget.item.discount == 0 ? '' : widget.item.discount.toString(),
    );
    _taxCtrl = TextEditingController(
      text: widget.item.gstRate == 0 ? '0' : widget.item.gstRate.toString(),
    );
    _makingChargesCtrl = TextEditingController(
      text: widget.item.makingCharges != null
          ? widget.item.makingCharges!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void didUpdateWidget(BillLineItemRow old) {
    super.didUpdateWidget(old);
    if (old.item.qty != widget.item.qty) {
      final formatted = widget.item.qty == widget.item.qty.roundToDouble()
          ? widget.item.qty.toInt().toString()
          : widget.item.qty.toString();
      if (_qtyCtrl.text != formatted) _qtyCtrl.text = formatted;
    }
    if (old.item.price != widget.item.price) {
      final formatted = widget.item.price.toStringAsFixed(2);
      if (_priceCtrl.text != formatted) _priceCtrl.text = formatted;
    }
    if (old.item.makingCharges != widget.item.makingCharges) {
      final formatted = widget.item.makingCharges != null
          ? widget.item.makingCharges!.toStringAsFixed(2)
          : '';
      if (_makingChargesCtrl.text != formatted) {
        _makingChargesCtrl.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discCtrl.dispose();
    _taxCtrl.dispose();
    _makingChargesCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final qty = double.tryParse(_qtyCtrl.text) ?? widget.item.qty;
    final price = double.tryParse(_priceCtrl.text) ?? widget.item.price;
    final discount = double.tryParse(_discCtrl.text) ?? 0.0;
    final gstRate = double.tryParse(_taxCtrl.text) ?? widget.item.gstRate;
    final taxableBase = qty * price * (1 - discount / 100);
    final taxAmt = taxableBase * gstRate / 100;
    final half = taxAmt / 2;

    widget.onUpdate(
      widget.item.copyWith(
        qty: qty,
        price: price,
        discount: discount,
        gstRate: gstRate,
        cgst: half,
        sgst: half,
      ),
    );
  }

  void _commitMakingCharges() {
    final makingCharges =
        double.tryParse(_makingChargesCtrl.text) ?? widget.item.makingCharges;
    widget.onUpdate(widget.item.copyWith(makingCharges: makingCharges));
  }

  bool get _isExpiredPharmacy {
    final exp = widget.item.expiryDate;
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _isExpiredPharmacy;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: BillTokens.rowHeight,
        decoration: BoxDecoration(
          color: isExpired
              ? BillTokens.expiredRowColor
              : (_hovered
                    ? BillTokens.rowHoverColor
                    : BillTokens.cardBackground),
          border: isExpired
              ? Border(
                  left: BorderSide(color: BillTokens.expiredBorder, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            // # Serial
            _cell(
              width: 36,
              child: Text(
                '${widget.serialNumber}',
                style: BillTokens.tableBody.copyWith(
                  color: BillTokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Item Name/Code with avatar
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    ProductAvatar(item: widget.item),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.productName,
                        style: BillTokens.tableBody.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isExpired)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Tooltip(
                          message: 'Expired: ${widget.item.expiryDate}',
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: BillTokens.expiredBorder,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Description (product name used as description — editable via edit icon)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.item.notes ?? '',
                  style: BillTokens.tableBody.copyWith(
                    color: BillTokens.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Qty
            _cell(
              width: 56,
              child: _inlineField(
                controller: _qtyCtrl,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onCommit: _commit,
              ),
            ),

            // Unit dropdown
            _cell(
              width: 68,
              child: _UnitDropdown(
                value: widget.item.unit,
                options: widget.unitOptions,
                onChanged: (val) {
                  widget.onUpdate(widget.item.copyWith(unit: val));
                },
              ),
            ),

            // Unit Price
            _cell(
              width: 80,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sl<CurrencyService>().symbol,
                    style: TextStyle(
                      fontSize: 11,
                      color: BillTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _inlineField(
                      controller: _priceCtrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onCommit: _commit,
                    ),
                  ),
                ],
              ),
            ),

            // Discount %
            _cell(
              width: 72,
              child: _inlineField(
                controller: _discCtrl,
                hint: '0',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onCommit: _commit,
              ),
            ),

            // Tax %
            _cell(
              width: 64,
              child: _inlineField(
                controller: _taxCtrl,
                hint: '0%',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onCommit: _commit,
              ),
            ),

            // Business-type extra columns (batch, expiry, serial, purity, etc.)
            if (widget.fieldConfig.showBatchNo)
              _cell(
                width: 72,
                child: Text(
                  widget.item.batchNo ?? '—',
                  style: BillTokens.tableBody.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),

            if (widget.fieldConfig.showExpiryDate)
              _cell(
                width: 84,
                child: Text(
                  widget.item.expiryDate != null
                      ? '${widget.item.expiryDate!.day}/${widget.item.expiryDate!.month}/${widget.item.expiryDate!.year}'
                      : '—',
                  style: BillTokens.tableBody.copyWith(
                    fontSize: 11,
                    color: isExpired
                        ? BillTokens.expiredBorder
                        : BillTokens.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            if (widget.fieldConfig.showSerialNo)
              _cell(
                width: 80,
                child: Text(
                  widget.item.serialNo ?? '—',
                  style: BillTokens.tableBody.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),

            if (widget.fieldConfig.showPurity)
              _cell(
                width: 72,
                child: _PurityDropdown(
                  value: widget.item.purity,
                  onChanged: (val) {
                    widget.onUpdate(widget.item.copyWith(purity: val));
                  },
                ),
              ),

            if (widget.fieldConfig.showWeight)
              _cell(
                width: 64,
                child: Text(
                  widget.item.metalWeight != null
                      ? '${widget.item.metalWeight!.toStringAsFixed(2)}g'
                      : '—',
                  style: BillTokens.tableBody.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),

            if (widget.fieldConfig.showMakingCharges)
              _cell(
                width: 88,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sl<CurrencyService>().symbol,
                      style: TextStyle(
                        fontSize: 11,
                        color: BillTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: _inlineField(
                        controller: _makingChargesCtrl,
                        hint: '0.00',
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onCommit: _commitMakingCharges,
                      ),
                    ),
                  ],
                ),
              ),

            // Total
            _cell(
              width: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sl<CurrencyService>().symbol,
                    style: TextStyle(
                      fontSize: 11,
                      color: BillTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    widget.item.total.toStringAsFixed(2),
                    style: BillTokens.tableBody.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            _cell(
              width: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: widget.onEdit,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: BillTokens.editIconColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: BillTokens.deleteIconColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell({required double width, required Widget child}) {
    return SizedBox(
      width: width,
      height: BillTokens.rowHeight,
      child: Center(child: child),
    );
  }

  Widget _inlineField({
    required TextEditingController controller,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    required VoidCallback onCommit,
  }) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: controller,
        inputFormatters: inputFormatters,
        style: BillTokens.tableBody,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: BillTokens.textSecondary,
            fontSize: 11,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 0,
          ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: BillTokens.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: BillTokens.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(
              color: BillTokens.primaryBlue,
              width: 1.5,
            ),
          ),
        ),
        onEditingComplete: onCommit,
        onTapOutside: (_) => onCommit(),
      ),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _UnitDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOptions = options.contains(value)
        ? options
        : [value, ...options];

    return SizedBox(
      height: 28,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 14,
            color: BillTokens.textSecondary,
          ),
          style: BillTokens.tableBody,
          items: effectiveOptions
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

/// Editable purity dropdown using GoldPurity enum values (24K, 22K, 18K, 14K).
/// Requirements: 13.3, 15.6 — replaces the read-only purity text cell.
/// Uses GoldPurity.displayLabel as the canonical String representation stored
/// in BillItem.purity, and GoldPurity.tryFromString to resolve the current value.
class _PurityDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _PurityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Resolve current value to a valid GoldPurity enum; show hint if unmatched
    final GoldPurity? currentPurity = GoldPurity.tryFromString(value);

    return SizedBox(
      height: 28,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GoldPurity>(
          value: currentPurity,
          isDense: true,
          isExpanded: true,
          hint: Text(
            '—',
            style: BillTokens.tableBody.copyWith(
              fontSize: 11,
              color: BillTokens.textSecondary,
            ),
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 14,
            color: BillTokens.textSecondary,
          ),
          style: BillTokens.tableBody.copyWith(fontSize: 11),
          items: GoldPurity.values
              .map(
                (p) => DropdownMenuItem<GoldPurity>(
                  value: p,
                  child: Text(p.displayLabel),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val.displayLabel);
          },
        ),
      ),
    );
  }
}

/// Table header row matching BillLineItemRow columns
class BillLineItemHeader extends StatelessWidget {
  final BillFieldConfig fieldConfig;

  const BillLineItemHeader({super.key, required this.fieldConfig});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: BillTokens.tableHeaderBg,
        border: Border(
          top: BorderSide(color: BillTokens.borderColor),
          bottom: BorderSide(color: BillTokens.borderColor),
        ),
      ),
      child: Row(
        children: [
          _header('#', 36, TextAlign.center),
          _headerExpanded('Item Name/Code', 4),
          _headerExpanded('Description', 3),
          _header('Qty', 56, TextAlign.center),
          _header('Unit', 68, TextAlign.center),
          _header('Unit Price', 80, TextAlign.center),
          _header('Discount (%)', 72, TextAlign.center),
          _header('Tax (%)', 64, TextAlign.center),
          if (fieldConfig.showBatchNo)
            _header('Batch No', 72, TextAlign.center),
          if (fieldConfig.showExpiryDate)
            _header('Expiry', 84, TextAlign.center),
          if (fieldConfig.showSerialNo)
            _header(
              fieldConfig.serialNoRequired ? 'Serial/IMEI *' : 'Serial/IMEI',
              80,
              TextAlign.center,
            ),
          if (fieldConfig.showPurity) _header('Purity', 72, TextAlign.center),
          if (fieldConfig.showWeight) _header('Wt (g)', 64, TextAlign.center),
          if (fieldConfig.showMakingCharges)
            _header('Making Chg', 88, TextAlign.center),
          _header('Total', 88, TextAlign.center),
          _header('', 60, TextAlign.center),
        ],
      ),
    );
  }

  Widget _header(String label, double width, TextAlign align) {
    return SizedBox(
      width: width,
      height: 36,
      child: Center(
        child: Text(label, style: BillTokens.tableHeader, textAlign: align),
      ),
    );
  }

  Widget _headerExpanded(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(label, style: BillTokens.tableHeader),
      ),
    );
  }
}

/// Empty state for line items table
class BillLineItemEmptyState extends StatelessWidget {
  final VoidCallback onAddItem;
  final VoidCallback onScanBarcode;

  const BillLineItemEmptyState({
    super.key,
    required this.onAddItem,
    required this.onScanBarcode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: BillTokens.borderColor,
          ),
          const SizedBox(height: 12),
          const Text(
            'No items added yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BillTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search for a product or scan a barcode to begin.',
            style: TextStyle(fontSize: 12, color: BillTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onScanBarcode,
                icon: const Icon(Icons.qr_code_scanner, size: 14),
                label: const Text('Scan Barcode'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BillTokens.primaryBlue,
                  side: const BorderSide(color: BillTokens.primaryBlue),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
