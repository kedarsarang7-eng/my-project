// ============================================================================
// MULTI-UNIT INPUT WIDGET — WHOLESALE BOX→PIECES CONVERSION
// ============================================================================
// Surfaces the box→pieces conversion input on wholesale item entry and billing
// when the `useMultiUnit` capability is granted.
//
// All arithmetic is integer paise-safe — no floating-point currency.
// Uses UnitConverter and PaiseMoney from the wholesale domain layer.
//
// Author: DukanX Engineering
// Requirement: 7.4, 7.5
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../domain/unit_converter.dart';
import '../../domain/paise_money.dart';

/// Computed result from the multi-unit conversion widget.
///
/// All monetary values are integer paise — no floating-point currency.
class MultiUnitResult {
  /// Number of boxes entered by the user.
  final int boxes;

  /// Conversion factor (pieces per box) from product config.
  final int factor;

  /// Total pieces = boxes × factor.
  final int totalPieces;

  /// Per-piece rate in paise.
  final int perPiecePaise;

  /// Line amount in paise = totalPieces × perPiecePaise.
  final int lineAmountPaise;

  const MultiUnitResult({
    required this.boxes,
    required this.factor,
    required this.totalPieces,
    required this.perPiecePaise,
    required this.lineAmountPaise,
  });
}

/// A widget that provides box→pieces multi-unit conversion for wholesale
/// item entry and billing.
///
/// Shows:
/// - A "Boxes" input field (user enters box count)
/// - A "Conversion Factor" display (pieces per box, from product config)
/// - Computed "Total Pieces" = boxes × factor
/// - Computed "Line Amount" = total pieces × per-piece rate (in paise,
///   displayed as rupees)
///
/// Only surfaced when the `useMultiUnit` capability is granted for the
/// wholesale business type. The caller is responsible for gating visibility.
///
/// All arithmetic is integer — no floating-point money.
class MultiUnitInputWidget extends StatefulWidget {
  /// The conversion factor (pieces per box) from product configuration.
  /// Must be > 0.
  final int conversionFactor;

  /// The per-piece rate in integer paise.
  final int perPiecePaise;

  /// Initial box count (defaults to 0).
  final int initialBoxes;

  /// Called whenever the computed values change.
  final ValueChanged<MultiUnitResult>? onChanged;

  const MultiUnitInputWidget({
    super.key,
    required this.conversionFactor,
    required this.perPiecePaise,
    this.initialBoxes = 0,
    this.onChanged,
  });

  @override
  State<MultiUnitInputWidget> createState() => _MultiUnitInputWidgetState();
}

class _MultiUnitInputWidgetState extends State<MultiUnitInputWidget> {
  late final TextEditingController _boxesController;
  static const _converter = UnitConverter();

  int _boxes = 0;
  int _totalPieces = 0;
  int _lineAmountPaise = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _boxes = widget.initialBoxes;
    _boxesController = TextEditingController(
      text: _boxes > 0 ? _boxes.toString() : '',
    );
    _recompute();
  }

  @override
  void didUpdateWidget(covariant MultiUnitInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversionFactor != widget.conversionFactor ||
        oldWidget.perPiecePaise != widget.perPiecePaise) {
      _recompute();
    }
  }

  @override
  void dispose() {
    _boxesController.dispose();
    super.dispose();
  }

  void _onBoxesChanged(String value) {
    final parsed = int.tryParse(value);
    setState(() {
      if (value.isEmpty) {
        _boxes = 0;
        _errorText = null;
      } else if (parsed == null || parsed < 0) {
        _boxes = 0;
        _errorText = 'Enter a valid number';
      } else {
        _boxes = parsed;
        _errorText = null;
      }
      _recompute();
    });
  }

  void _recompute() {
    if (widget.conversionFactor <= 0) {
      _totalPieces = 0;
      _lineAmountPaise = 0;
      _errorText = 'Invalid conversion factor';
      return;
    }

    _totalPieces = _converter.boxesToPieces(
      boxes: _boxes,
      factor: widget.conversionFactor,
    );
    _lineAmountPaise = _converter.lineAmountPaise(
      pieces: _totalPieces,
      perPiecePaise: widget.perPiecePaise,
    );

    widget.onChanged?.call(
      MultiUnitResult(
        boxes: _boxes,
        factor: widget.conversionFactor,
        totalPieces: _totalPieces,
        perPiecePaise: widget.perPiecePaise,
        lineAmountPaise: _lineAmountPaise,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? FuturisticColors.primary.withOpacity(0.08)
            : FuturisticColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FuturisticColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: FuturisticColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Multi-Unit Conversion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Boxes input + Conversion factor display
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Boxes input
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _boxesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onBoxesChanged,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: _buildInputDecoration(
                    'Boxes',
                    Icons.add_box_outlined,
                    isDark,
                    errorText: _errorText,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Conversion factor (read-only display)
              Expanded(
                flex: 3,
                child: _buildReadOnlyField(
                  label: 'Factor (pcs/box)',
                  value: widget.conversionFactor.toString(),
                  icon: Icons.close,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Computed results row
          Row(
            children: [
              // Total pieces
              Expanded(
                child: _buildComputedField(
                  label: 'Total Pieces',
                  value: _totalPieces.toString(),
                  icon: Icons.grid_view_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              // Line amount
              Expanded(
                child: _buildComputedField(
                  label: 'Line Amount',
                  value: PaiseMoney.formatRupees(_lineAmountPaise),
                  icon: Icons.currency_rupee,
                  isDark: isDark,
                  highlight: true,
                ),
              ),
            ],
          ),

          // Per-piece rate info
          const SizedBox(height: 12),
          Text(
            'Per-piece rate: ${PaiseMoney.formatRupees(widget.perPiecePaise)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData? icon,
    bool isDark, {
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
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

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComputedField({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? FuturisticColors.primary.withOpacity(isDark ? 0.15 : 0.08)
            : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? FuturisticColors.primary.withOpacity(0.3)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: highlight
                    ? FuturisticColors.primary
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: highlight
                        ? FuturisticColors.primary
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
