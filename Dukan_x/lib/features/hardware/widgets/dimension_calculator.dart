// ============================================================================
// DIMENSION CALCULATOR WIDGET — Hardware Shop
// ============================================================================
// Calculates area from length × width for materials sold by Sq.ft/Sq.mtr
//
// Example: Plywood sheet 8ft × 4ft = 32 Sq.ft
//          Glass panel 2.5m × 1.2m = 3 Sq.mtr
//
// Features:
// - Automatic calculation as user types
// - Unit conversion (ft ↔ mtr)
// - Preset common sizes (4×8, 4×6, etc.)
// - Validation for reasonable dimensions
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Result of dimension calculation
class DimensionResult {
  final double length;
  final double width;
  final String unit; // 'ft' or 'mtr'
  final double area;
  final String areaUnit; // 'sqft' or 'sqmtr'

  const DimensionResult({
    required this.length,
    required this.width,
    required this.unit,
    required this.area,
    required this.areaUnit,
  });

  /// Format as display string (e.g., "8.0 × 4.0 ft = 32.0 Sq.Ft")
  String get displayString =>
      '${length.toStringAsFixed(2)} × ${width.toStringAsFixed(2)} $unit = ${area.toStringAsFixed(2)} $areaUnit';

  /// Format dimensions only (e.g., "8.0 × 4.0 ft")
  String get dimensionsOnly =>
      '${length.toStringAsFixed(2)} × ${width.toStringAsFixed(2)} $unit';
}

/// Preset dimension templates for common hardware materials
class DimensionPreset {
  final String name;
  final double length;
  final double width;
  final String unit;

  const DimensionPreset({
    required this.name,
    required this.length,
    required this.width,
    required this.unit,
  });

  static const List<DimensionPreset> commonPresets = [
    // Plywood/MDF standard sizes
    DimensionPreset(
      name: 'Plywood Full (8×4)',
      length: 8,
      width: 4,
      unit: 'ft',
    ),
    DimensionPreset(
      name: 'Plywood Half (8×2)',
      length: 8,
      width: 2,
      unit: 'ft',
    ),
    DimensionPreset(
      name: 'Plywood Quarter (4×2)',
      length: 4,
      width: 2,
      unit: 'ft',
    ),
    // Commercial board sizes
    DimensionPreset(name: 'Board 6×4', length: 6, width: 4, unit: 'ft'),
    DimensionPreset(name: 'Board 6×3', length: 6, width: 3, unit: 'ft'),
    DimensionPreset(name: 'Board 5×3', length: 5, width: 3, unit: 'ft'),
    // Metric sizes
    DimensionPreset(
      name: 'Sheet 2440×1220mm',
      length: 2.44,
      width: 1.22,
      unit: 'mtr',
    ),
    DimensionPreset(
      name: 'Sheet 1830×1220mm',
      length: 1.83,
      width: 1.22,
      unit: 'mtr',
    ),
  ];
}

/// Dimension Calculator Widget
class DimensionCalculator extends StatefulWidget {
  final Function(DimensionResult)? onCalculate;
  final String? initialDimensions; // e.g., "8 × 4 ft"
  final bool showPresets;

  const DimensionCalculator({
    super.key,
    this.onCalculate,
    this.initialDimensions,
    this.showPresets = true,
  });

  @override
  State<DimensionCalculator> createState() => _DimensionCalculatorState();
}

class _DimensionCalculatorState extends State<DimensionCalculator> {
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  String _unit = 'ft';
  DimensionResult? _result;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _parseInitialDimensions();
    _lengthCtrl.addListener(_onInputChanged);
    _widthCtrl.addListener(_onInputChanged);
  }

  void _parseInitialDimensions() {
    if (widget.initialDimensions == null) return;

    // Parse format: "8 × 4 ft" or "2.5 × 1.2 mtr"
    final parts = widget.initialDimensions!.split('×');
    if (parts.length == 2) {
      final length = double.tryParse(parts[0].trim()) ?? 0;
      final widthParts = parts[1].trim().split(' ');
      final width = double.tryParse(widthParts[0]) ?? 0;
      final unit = widthParts.length > 1 ? widthParts[1] : 'ft';

      if (length > 0 && width > 0) {
        _lengthCtrl.text = length.toString();
        _widthCtrl.text = width.toString();
        _unit = unit == 'mtr' ? 'mtr' : 'ft';
        _calculate();
      }
    }
  }

  void _onInputChanged() {
    _calculate();
  }

  void _calculate() {
    final length = double.tryParse(_lengthCtrl.text) ?? 0;
    final width = double.tryParse(_widthCtrl.text) ?? 0;

    // Validation
    if (length <= 0 || width <= 0) {
      setState(() {
        _result = null;
        _errorText = null;
      });
      return;
    }

    // Sanity checks
    if (length > 100 || width > 100) {
      setState(() {
        _errorText = 'Dimensions seem too large. Max 100 ft/mtr.';
        _result = null;
      });
      return;
    }

    if (length < 0.1 || width < 0.1) {
      setState(() {
        _errorText = 'Dimensions too small. Min 0.1 ft/mtr.';
        _result = null;
      });
      return;
    }

    // Calculate area
    final area = length * width;
    final areaUnit = _unit == 'ft' ? 'sqft' : 'sqmtr';

    final result = DimensionResult(
      length: length,
      width: width,
      unit: _unit,
      area: area,
      areaUnit: areaUnit,
    );

    setState(() {
      _result = result;
      _errorText = null;
    });

    widget.onCalculate?.call(result);
  }

  void _applyPreset(DimensionPreset preset) {
    setState(() {
      _lengthCtrl.text = preset.length.toString();
      _widthCtrl.text = preset.width.toString();
      _unit = preset.unit;
    });
    _calculate();
  }

  void _switchUnit() {
    setState(() {
      _unit = _unit == 'ft' ? 'mtr' : 'ft';

      // Convert existing values
      if (_lengthCtrl.text.isNotEmpty && _widthCtrl.text.isNotEmpty) {
        final length = double.tryParse(_lengthCtrl.text) ?? 0;
        final width = double.tryParse(_widthCtrl.text) ?? 0;

        if (_unit == 'mtr') {
          // ft → mtr
          _lengthCtrl.text = (length * 0.3048).toStringAsFixed(2);
          _widthCtrl.text = (width * 0.3048).toStringAsFixed(2);
        } else {
          // mtr → ft
          _lengthCtrl.text = (length / 0.3048).toStringAsFixed(2);
          _widthCtrl.text = (width / 0.3048).toStringAsFixed(2);
        }
      }
    });
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with unit toggle
            Row(
              children: [
                Icon(Icons.square_foot, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Area Calculator',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                _UnitToggle(value: _unit, onToggle: _switchUnit),
              ],
            ),
            const SizedBox(height: 16),

            // Input fields
            Row(
              children: [
                Expanded(
                  child: _DimensionInput(
                    label: 'Length',
                    controller: _lengthCtrl,
                    unit: _unit,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('×', style: TextStyle(fontSize: 20)),
                ),
                Expanded(
                  child: _DimensionInput(
                    label: 'Width',
                    controller: _widthCtrl,
                    unit: _unit,
                  ),
                ),
              ],
            ),

            // Error message
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ],

            // Result display
            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Area: ${_result!.area.toStringAsFixed(2)} ${_result!.areaUnit == 'sqft' ? 'Sq.Ft' : 'Sq.Mtr'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Presets
            if (widget.showPresets) ...[
              const SizedBox(height: 16),
              Text(
                'Common Sizes:',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DimensionPreset.commonPresets.map((preset) {
                  return ActionChip(
                    label: Text(preset.name),
                    onPressed: () => _applyPreset(preset),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }
}

class _DimensionInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;

  const _DimensionInput({
    required this.label,
    required this.controller,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String value;
  final VoidCallback onToggle;

  const _UnitToggle({required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value == 'ft' ? 'Feet' : 'Metre',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.swap_horiz, size: 16, color: cs.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
}
