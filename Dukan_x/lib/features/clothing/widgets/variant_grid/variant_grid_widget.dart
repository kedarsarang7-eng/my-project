import 'package:flutter/material.dart';
import 'variant_cell.dart';
import 'variant_cell_key.dart';
import 'size_curve_chip.dart';

class VariantGridWidget extends StatefulWidget {
  final List<String> sizes;
  final List<String> colors;
  final Map<String, int> initialQuantities; // key: variantCellKey(color, size)
  final ValueChanged<Map<String, int>> onQuantitiesChanged;

  /// Callback invoked when the explicit Save control is activated.
  /// Returns a Future that resolves to true on success, false on failure.
  final Future<bool> Function(Map<String, int> quantities)? onSave;

  /// Whether a save operation is currently in progress.
  final bool isSaving;

  const VariantGridWidget({
    super.key,
    required this.sizes,
    required this.colors,
    this.initialQuantities = const {},
    required this.onQuantitiesChanged,
    this.onSave,
    this.isSaving = false,
  });

  @override
  State<VariantGridWidget> createState() => _VariantGridWidgetState();
}

class _VariantGridWidgetState extends State<VariantGridWidget> {
  late Map<String, int> _quantities;

  // Example curves
  final Map<String, Map<String, int>> _commonCurves = {
    'Standard Curve': {'S': 1, 'M': 2, 'L': 2, 'XL': 1},
    'Plus Size Curve': {'L': 1, 'XL': 2, 'XXL': 2, '3XL': 1},
  };

  @override
  void initState() {
    super.initState();
    _quantities = Map.from(widget.initialQuantities);
  }

  void _updateQuantity(String color, String size, int qty) {
    // Reject out-of-bounds quantity: negative or > 999,999 (Req 14.10)
    if (qty < 0 || qty > 999999) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quantity must be between 0 and 999,999. '
            'Value "$qty" for $color / $size rejected.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return; // preserve the prior value
    }

    setState(() {
      final key = variantCellKey(color, size);
      if (qty <= 0) {
        _quantities.remove(key);
      } else {
        _quantities[key] = qty;
      }
    });
    widget.onQuantitiesChanged(_quantities);
  }

  void _applyCurveToRow(String color, Map<String, int> curveRatios) {
    setState(() {
      for (final entry in curveRatios.entries) {
        final size = entry.key;
        if (widget.sizes.contains(size)) {
          _quantities[variantCellKey(color, size)] = entry.value;
        }
      }
    });
    widget.onQuantitiesChanged(_quantities);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Curves Section
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Text(
                'Smart Fill: ',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              ..._commonCurves.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SizeCurveChip(
                    label: e.key,
                    curveRatios: e.value,
                    onApply: () {
                      // Apply to all colors if clicked here
                      for (var c in widget.colors) {
                        _applyCurveToRow(c, e.value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grid Section
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final numColumns =
                    widget.sizes.length + 1; // +1 for color header column
                final columnWidth = (constraints.maxWidth / numColumns).clamp(
                  120.0,
                  double.infinity,
                );

                return Table(
                  border: TableBorder.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                  defaultColumnWidth: FixedColumnWidth(columnWidth),
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      children: [
                        const VariantCell(
                          isHeader: true,
                          headerText: 'Color / Size',
                        ),
                        ...widget.sizes.map(
                          (s) => VariantCell(isHeader: true, headerText: s),
                        ),
                      ],
                    ),
                    // Data Rows
                    ...widget.colors.map((color) {
                      return TableRow(
                        children: [
                          // Row Header
                          VariantCell(isHeader: true, headerText: color),
                          // Data Cells
                          ...widget.sizes.map((size) {
                            final key = variantCellKey(color, size);
                            return VariantCell(
                              initialValue: _quantities[key] ?? 0,
                              onChanged: (val) =>
                                  _updateQuantity(color, size, val),
                              color: color,
                              size: size,
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),

        // Explicit Save control (Requirement 8.1)
        if (widget.onSave != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: widget.isSaving
                    ? null
                    : () => widget.onSave!(_quantities),
                icon: widget.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(widget.isSaving ? 'Saving…' : 'Save Quantities'),
              ),
            ),
          ),
      ],
    );
  }
}
