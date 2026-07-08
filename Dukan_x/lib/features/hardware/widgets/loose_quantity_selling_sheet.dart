// ============================================================================
// LOOSE-QUANTITY / CUT-TO-LENGTH SELLING WIDGET — Hardware Shop
// ============================================================================
// Workflow for selling items by cut length (bars, pipes, rods, wires, etc.)
//
// Example: 6ft iron bar at ₹100/ft — customer needs 1.3ft
//          Charge = cutToSizeCharge(100, 1.3) = ₹200 (rounds up to 2ft)
//          Remnant = 6 - 1.3 = 4.7ft (tracked for next customer)
//
// Features:
// - Select item from stock (bar/pipe/sheet items sold by ft/mtr)
// - Enter cut length needed
// - Auto-calculate charge using HardwareBusinessRules.cutToSizeCharge()
// - Show rounding disclosure via cutToSizeRoundingNote()
// - Track remnant inventory (original stock - cut length)
// - Persist remnant to local DB via HardwareOpsRepository
//
// Requirement: 1.11, 2.11 (HARDWARE-011)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/hardware_ops_repository.dart';
import '../utils/hardware_business_rules.dart';

/// Model for a remnant record persisted locally.
class RemnantRecord {
  final String id;
  final String itemName;
  final double remainingLength;
  final String unit;
  final double pricePerUnit;
  final DateTime createdAt;
  final String? notes;

  const RemnantRecord({
    required this.id,
    required this.itemName,
    required this.remainingLength,
    required this.unit,
    required this.pricePerUnit,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_name': itemName,
    'remaining_length': remainingLength,
    'unit': unit,
    'price_per_unit': pricePerUnit,
    'created_at': createdAt.toIso8601String(),
    'notes': notes,
  };

  factory RemnantRecord.fromJson(Map<String, dynamic> json) => RemnantRecord(
    id: json['id'] as String,
    itemName: json['item_name'] as String,
    remainingLength: (json['remaining_length'] as num).toDouble(),
    unit: json['unit'] as String,
    pricePerUnit: (json['price_per_unit'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
    notes: json['notes'] as String?,
  );
}

/// Result emitted when a loose-quantity sale is confirmed.
class LooseQuantitySaleResult {
  final String itemName;
  final double cutLength;
  final double billableUnits;
  final double chargeAmount;
  final double remnantLength;
  final String unit;
  final String? roundingNote;

  const LooseQuantitySaleResult({
    required this.itemName,
    required this.cutLength,
    required this.billableUnits,
    required this.chargeAmount,
    required this.remnantLength,
    required this.unit,
    this.roundingNote,
  });
}

/// Loose-quantity / cut-to-length selling bottom sheet widget.
///
/// Integrates with:
/// - [HardwareBusinessRules.cutToSizeCharge] for charge calculation
/// - [HardwareBusinessRules.cutToSizeRoundingNote] for disclosure
/// - [HardwareOpsRepository] for remnant persistence (local-first)
class LooseQuantitySellingSheet extends StatefulWidget {
  /// Callback when a sale is confirmed.
  final void Function(LooseQuantitySaleResult result)? onSaleConfirmed;

  /// Optional pre-selected item name.
  final String? initialItemName;

  /// Optional stock length of the item (e.g., 6ft bar).
  final double? stockLength;

  /// Unit of measurement (ft, mtr, etc.)
  final String unit;

  /// Price per unit of the item.
  final double? pricePerUnit;

  /// Repository for remnant persistence. If null, uses a default instance.
  final HardwareOpsRepository? repository;

  const LooseQuantitySellingSheet({
    super.key,
    this.onSaleConfirmed,
    this.initialItemName,
    this.stockLength,
    this.unit = 'ft',
    this.pricePerUnit,
    this.repository,
  });

  @override
  State<LooseQuantitySellingSheet> createState() =>
      _LooseQuantitySellingSheetState();
}

class _LooseQuantitySellingSheetState extends State<LooseQuantitySellingSheet> {
  final _itemNameCtrl = TextEditingController();
  final _stockLengthCtrl = TextEditingController();
  final _cutLengthCtrl = TextEditingController();
  final _pricePerUnitCtrl = TextEditingController();

  late final HardwareOpsRepository _repo;

  double? _chargeAmount;
  double? _remnantLength;
  String? _roundingNote;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? HardwareOpsRepository();

    if (widget.initialItemName != null) {
      _itemNameCtrl.text = widget.initialItemName!;
    }
    if (widget.stockLength != null) {
      _stockLengthCtrl.text = widget.stockLength!.toString();
    }
    if (widget.pricePerUnit != null) {
      _pricePerUnitCtrl.text = widget.pricePerUnit!.toString();
    }

    _cutLengthCtrl.addListener(_recalculate);
    _stockLengthCtrl.addListener(_recalculate);
    _pricePerUnitCtrl.addListener(_recalculate);
  }

  void _recalculate() {
    final stockLength = double.tryParse(_stockLengthCtrl.text) ?? 0;
    final cutLength = double.tryParse(_cutLengthCtrl.text) ?? 0;
    final pricePerUnit = double.tryParse(_pricePerUnitCtrl.text) ?? 0;

    setState(() {
      _errorText = null;
      _chargeAmount = null;
      _remnantLength = null;
      _roundingNote = null;
    });

    if (cutLength <= 0 || pricePerUnit <= 0) return;

    if (stockLength > 0 && cutLength > stockLength) {
      setState(() {
        _errorText =
            'Cut length cannot exceed stock length '
            '(${stockLength.toStringAsFixed(2)} ${widget.unit})';
      });
      return;
    }

    final charge = HardwareBusinessRules.cutToSizeCharge(
      pricePerUnit,
      cutLength,
    );

    final remnant = stockLength > 0 ? stockLength - cutLength : null;

    final roundingNote = HardwareBusinessRules.cutToSizeRoundingNote(
      cutLength,
      unitLabel: widget.unit,
    );

    setState(() {
      _chargeAmount = charge;
      _remnantLength = remnant;
      _roundingNote = roundingNote;
    });
  }

  Future<void> _confirmSale() async {
    final itemName = _itemNameCtrl.text.trim();
    final stockLength = double.tryParse(_stockLengthCtrl.text) ?? 0;
    final cutLength = double.tryParse(_cutLengthCtrl.text) ?? 0;
    final pricePerUnit = double.tryParse(_pricePerUnitCtrl.text) ?? 0;

    if (itemName.isEmpty) {
      setState(() => _errorText = 'Please enter an item name.');
      return;
    }
    if (cutLength <= 0) {
      setState(() => _errorText = 'Please enter the cut length.');
      return;
    }
    if (pricePerUnit <= 0) {
      setState(() => _errorText = 'Please enter the price per unit.');
      return;
    }

    setState(() => _saving = true);

    try {
      // Calculate billable units (rounded up)
      final billableUnits = cutLength.ceilToDouble();
      final charge = HardwareBusinessRules.cutToSizeCharge(
        pricePerUnit,
        cutLength,
      );
      final remnant = stockLength > 0 ? stockLength - cutLength : 0.0;

      // Persist remnant to local DB if there's remaining stock
      if (remnant > 0) {
        await _persistRemnant(
          itemName: itemName,
          remainingLength: remnant,
          pricePerUnit: pricePerUnit,
        );
      }

      final result = LooseQuantitySaleResult(
        itemName: itemName,
        cutLength: cutLength,
        billableUnits: billableUnits,
        chargeAmount: charge,
        remnantLength: remnant,
        unit: widget.unit,
        roundingNote: HardwareBusinessRules.cutToSizeRoundingNote(
          cutLength,
          unitLabel: widget.unit,
        ),
      );

      widget.onSaleConfirmed?.call(result);

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      setState(() {
        _errorText = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  /// Persist the remnant record to the local-first hardware DB via
  /// [HardwareOpsRepository], which uses Drift for local storage and
  /// enqueues for background sync.
  Future<void> _persistRemnant({
    required String itemName,
    required double remainingLength,
    required double pricePerUnit,
  }) async {
    final now = DateTime.now().toIso8601String();
    // Use the local-first repository's raw insert for the remnants table
    await _repo.saveRemnant(
      itemName: itemName,
      remainingLength: remainingLength,
      unit: widget.unit,
      pricePerUnit: pricePerUnit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.content_cut, size: 22, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Cut-to-Length Sale',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Item name
            TextField(
              controller: _itemNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                hintText: 'e.g., MS Bar 12mm, PVC Pipe 1"',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Stock length + Price per unit in a row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockLengthCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Stock Length',
                      suffixText: widget.unit,
                      border: const OutlineInputBorder(),
                      hintText: 'e.g., 6',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pricePerUnitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Price / ${widget.unit}',
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cut length
            TextField(
              controller: _cutLengthCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Cut Length Needed',
                suffixText: widget.unit,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.straighten),
                hintText: 'e.g., 1.3',
              ),
            ),
            const SizedBox(height: 16),

            // Error
            if (_errorText != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: TextStyle(color: cs.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Calculation result
            if (_chargeAmount != null) ...[
              _ResultCard(
                chargeAmount: _chargeAmount!,
                remnantLength: _remnantLength,
                roundingNote: _roundingNote,
                unit: widget.unit,
              ),
              const SizedBox(height: 16),
            ],

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _chargeAmount == null
                    ? null
                    : _confirmSale,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving...' : 'Confirm Sale'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _stockLengthCtrl.dispose();
    _cutLengthCtrl.dispose();
    _pricePerUnitCtrl.dispose();
    super.dispose();
  }
}

/// Displays the calculated charge, remnant, and rounding note.
class _ResultCard extends StatelessWidget {
  final double chargeAmount;
  final double? remnantLength;
  final String? roundingNote;
  final String unit;

  const _ResultCard({
    required this.chargeAmount,
    this.remnantLength,
    this.roundingNote,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Charge amount
            Row(
              children: [
                Icon(Icons.currency_rupee, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Charge: ₹${chargeAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),

            // Remnant info
            if (remnantLength != null && remnantLength! > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.inventory, color: cs.tertiary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Remnant: ${remnantLength!.toStringAsFixed(2)} $unit remaining',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ],

            // Rounding disclosure
            if (roundingNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: cs.tertiary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        roundingNote!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
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
}
