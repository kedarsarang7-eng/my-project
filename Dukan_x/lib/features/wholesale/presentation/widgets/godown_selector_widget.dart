import 'package:flutter/material.dart';

import '../../domain/warehouse.dart';

/// A dropdown/picker that shows warehouses (godowns) for the current tenant.
///
/// Used on inventory and billing surfaces where a stock location is required.
/// Emits the selected warehouse/location id via [onSelected].
///
/// Phase 7 (§2; Requirement 10.2, 10.5).
class GodownSelectorWidget extends StatelessWidget {
  /// The list of warehouses available for the current tenant.
  final List<Warehouse> warehouses;

  /// The currently selected warehouse id (null if none selected).
  final String? selectedWarehouseId;

  /// Callback emitting the selected warehouse id when the user picks one.
  final ValueChanged<String> onSelected;

  /// Optional label text for the dropdown.
  final String label;

  /// Whether the selector is enabled for interaction.
  final bool enabled;

  const GodownSelectorWidget({
    super.key,
    required this.warehouses,
    required this.selectedWarehouseId,
    required this.onSelected,
    this.label = 'Select Godown',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (warehouses.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: false,
        ),
        child: Text(
          'No godowns configured',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedWarehouseId,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.warehouse_outlined),
      ),
      items: warehouses
          .map(
            (w) => DropdownMenuItem<String>(
              value: w.id,
              child: Text(w.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled
          ? (value) {
              if (value != null) {
                onSelected(value);
              }
            }
          : null,
      hint: const Text('Choose a godown'),
      isExpanded: true,
    );
  }
}
