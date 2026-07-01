import 'package:flutter/material.dart';

class VariantMatrixSelection extends StatefulWidget {
  final List<String> sizes;
  final List<String> colors;
  final Map<String, double> initialQuantities;
  final Function(Map<String, double>) onChanged;

  const VariantMatrixSelection({
    super.key,
    required this.sizes,
    required this.colors,
    this.initialQuantities = const {},
    required this.onChanged,
  });

  @override
  State<VariantMatrixSelection> createState() => _VariantMatrixSelectionState();
}

class _VariantMatrixSelectionState extends State<VariantMatrixSelection> {
  late Map<String, double> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = Map.from(widget.initialQuantities);
  }

  void _updateQuantity(String size, String color, String value) {
    final key = '$size-$color';
    final qty = double.tryParse(value) ?? 0.0;

    setState(() {
      if (qty > 0) {
        _quantities[key] = qty;
      } else {
        _quantities.remove(key);
      }
    });

    widget.onChanged(_quantities);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Variant Matrix (Size x Color)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(80),
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: [
                      const TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Size \\ Color',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      ...widget.colors.map(
                        (c) => TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Data Rows
                  ...widget.sizes.map((size) {
                    return TableRow(
                      children: [
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              size,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        ...widget.colors.map((color) {
                          final key = '$size-$color';
                          return TableCell(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: TextFormField(
                                initialValue:
                                    _quantities[key]?.toString() ?? '',
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 4,
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (val) =>
                                    _updateQuantity(size, color, val),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
