// ============================================================================
// MODIFIER PICKER SHEET
// ============================================================================
// Bottom sheet that displays available variations/modifiers for a restaurant
// menu item and allows selection. Backs Requirement 2.10.
//
// The selected modifier IDs and cumulative price delta are returned to the
// caller for writing onto the BillItem's `modifierIds` / `modifierPriceDelta`.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/food_item_variation_model.dart';
import '../../data/repositories/food_item_variation_repository.dart';
import '../../../../core/di/service_locator.dart';

/// Result returned from the modifier picker containing the user's selections.
class ModifierPickerResult {
  final List<String> modifierIds;
  final double modifierPriceDelta;

  const ModifierPickerResult({
    required this.modifierIds,
    required this.modifierPriceDelta,
  });
}

/// Shows a bottom sheet for picking modifiers/variations for a restaurant
/// menu item. Returns [ModifierPickerResult] or null if cancelled.
Future<ModifierPickerResult?> showModifierPickerSheet({
  required BuildContext context,
  required String itemId,
  required String itemName,
  required double basePrice,
  List<String>? currentModifierIds,
}) {
  return showModalBottomSheet<ModifierPickerResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ModifierPickerSheet(
      itemId: itemId,
      itemName: itemName,
      basePrice: basePrice,
      currentModifierIds: currentModifierIds,
    ),
  );
}

class _ModifierPickerSheet extends StatefulWidget {
  final String itemId;
  final String itemName;
  final double basePrice;
  final List<String>? currentModifierIds;

  const _ModifierPickerSheet({
    required this.itemId,
    required this.itemName,
    required this.basePrice,
    this.currentModifierIds,
  });

  @override
  State<_ModifierPickerSheet> createState() => _ModifierPickerSheetState();
}

class _ModifierPickerSheetState extends State<_ModifierPickerSheet> {
  late final FoodItemVariationRepository _variationRepo;
  List<FoodItemVariation> _variations = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _variationRepo = sl<FoodItemVariationRepository>();
    _selectedIds.addAll(widget.currentModifierIds ?? []);
    _loadVariations();
  }

  Future<void> _loadVariations() async {
    final result = await _variationRepo.getVariationsForItem(widget.itemId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _variations = result.data!;
      } else {
        _error = result.errorMessage ?? 'Failed to load modifiers';
      }
    });
  }

  double get _priceDelta {
    double delta = 0;
    for (final variation in _variations) {
      if (_selectedIds.contains(variation.id)) {
        // Price delta is the variation price minus the base item price
        // (variation.price represents the full price for that variation)
        delta += variation.price - widget.basePrice;
      }
    }
    return delta;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).primaryColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modifiers',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.itemName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _priceDelta >= 0
                            ? '+₹${_priceDelta.toStringAsFixed(2)}'
                            : '-₹${_priceDelta.abs().toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: _buildContent(isDark, accentColor, scrollController),
            ),
            // Confirm button
            _buildFooter(isDark, accentColor),
          ],
        );
      },
    );
  }

  Widget _buildContent(
    bool isDark,
    Color accentColor,
    ScrollController scrollController,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)),
      );
    }

    if (_variations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 48,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No modifiers available',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add variations in Menu Management',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _variations.length,
      itemBuilder: (context, index) {
        final variation = _variations[index];
        final isSelected = _selectedIds.contains(variation.id);
        final priceDiff = variation.price - widget.basePrice;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.1)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.white12 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? accentColor : Colors.grey,
            ),
            title: Text(
              variation.name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            trailing: Text(
              priceDiff == 0
                  ? '₹${variation.price.toStringAsFixed(0)}'
                  : priceDiff > 0
                  ? '+₹${priceDiff.toStringAsFixed(0)}'
                  : '-₹${priceDiff.abs().toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(variation.id);
                } else {
                  _selectedIds.add(variation.id);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildFooter(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selectedIds.clear()),
              child: Text(
                'Clear All',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              if (_selectedIds.isEmpty) {
                // Return null modifiers (clear)
                Navigator.of(context).pop(
                  const ModifierPickerResult(
                    modifierIds: [],
                    modifierPriceDelta: 0,
                  ),
                );
              } else {
                Navigator.of(context).pop(
                  ModifierPickerResult(
                    modifierIds: _selectedIds.toList(),
                    modifierPriceDelta: _priceDelta,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _selectedIds.isEmpty
                  ? 'No Modifiers'
                  : 'Apply (${_selectedIds.length})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
