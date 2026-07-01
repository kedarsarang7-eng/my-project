// Adaptive Item Card Widget
// Dynamic item card that renders different fields based on business type
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/billing/business_strategy_factory.dart';
import '../../../../core/billing/business_type_config.dart';
import '../../../../models/bill.dart';

/// Adaptive Item Card that shows fields based on business type
class AdaptiveItemCard extends StatefulWidget {
  final BillItem item;
  final int index;
  final BusinessType businessType;
  final bool isDarkMode;
  final Color accentColor;
  final Function(BillItem updatedItem) onUpdate;
  final VoidCallback onRemove;

  const AdaptiveItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.businessType,
    required this.isDarkMode,
    required this.accentColor,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<AdaptiveItemCard> createState() => _AdaptiveItemCardState();
}

class _AdaptiveItemCardState extends State<AdaptiveItemCard> {
  late BusinessTypeConfig _config;

  @override
  void initState() {
    super.initState();
    _config = BusinessTypeRegistry.getConfig(widget.businessType);
  }

  @override
  void didUpdateWidget(AdaptiveItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessType != widget.businessType) {
      _config = BusinessTypeRegistry.getConfig(widget.businessType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with serial number and remove button
          _buildHeader(isDark),

          // Main content based on business type
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildBusinessContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          // Serial number badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.accentColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${widget.index + 1}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Item name
          Expanded(
            child: Text(
              widget.item.itemName.isEmpty
                  ? _config.itemLabel
                  : widget.item.itemName,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Total amount
          Text(
            '₹${widget.item.total.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(width: 8),

          // Remove button
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
              size: 20,
            ),
            onPressed: widget.onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessContent(bool isDark) {
    // Strategy Pattern: Delegate UI building to the specific strategy
    final strategy = BusinessStrategyFactory.getStrategy(widget.businessType);
    return strategy.buildItemFields(
      context,
      widget.item,
      widget.onUpdate,
      isDark,
      widget.accentColor,
    );
  }
}
