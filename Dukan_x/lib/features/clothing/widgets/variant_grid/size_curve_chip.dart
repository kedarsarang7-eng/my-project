import 'package:flutter/material.dart';

class SizeCurveChip extends StatelessWidget {
  final String label;
  final Map<String, int> curveRatios;
  final VoidCallback onApply;

  const SizeCurveChip({
    super.key,
    required this.label,
    required this.curveRatios,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.auto_graph, size: 16),
      label: Text(label),
      onPressed: onApply,
      tooltip: 'Apply Curve: ${curveRatios.entries.map((e) => '${e.key}:${e.value}').join(', ')}',
    );
  }
}
