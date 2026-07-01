// ============================================================================
// BILL CREATION DESIGN TOKENS
// ============================================================================
// Single source of truth for all visual constants in the bill creation screen.
// No magic numbers anywhere in the bill creation feature.
// ============================================================================

import 'package:flutter/material.dart';

abstract class BillTokens {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color pageBackground = Color(0xFFF8F9FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color tableHeaderBg = Color(0xFFF1F3F4);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color draftBadgeBg = Color(0xFFFFF3E0);
  static const Color draftBadgeFg = Color(0xFFE65100);
  static const Color deleteIconColor = Color(0xFFE53935);
  static const Color editIconColor = Color(0xFF1A73E8);
  static const Color rowHoverColor = Color(0xFFF8F9FA);
  static const Color expiredRowColor = Color(0xFFFFF8E1);
  static const Color expiredBorder = Color(0xFFFFB300);

  // ── Shadows ───────────────────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  // ── Border radii ──────────────────────────────────────────────────────────
  static const double cardRadius = 8.0;
  static const double inputRadius = 6.0;
  static const double buttonRadius = 6.0;
  static const double badgeRadius = 12.0;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double pagePadding = 16.0;
  static const double cardPadding = 16.0;
  static const double sectionGap = 12.0;
  static const double rowHeight = 48.0;
  static const double avatarSize = 32.0;

  // ── Typography ────────────────────────────────────────────────────────────
  static const TextStyle pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle tableHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle tableBody = TextStyle(
    fontSize: 13,
    color: textPrimary,
  );

  static const TextStyle totalLabel = TextStyle(
    fontSize: 13,
    color: textSecondary,
  );

  static const TextStyle grandTotalLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle grandTotalValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );

  // ── Category icon color map ───────────────────────────────────────────────
  static const Map<String, IconData> categoryIconMap = {
    'laptop': Icons.laptop_mac,
    'computer': Icons.computer,
    'mobile': Icons.smartphone,
    'clothing': Icons.checkroom,
    'shirt': Icons.checkroom,
    'tools': Icons.build,
    'hardware': Icons.hardware,
    'medicine': Icons.medication,
    'pharmacy': Icons.local_pharmacy,
    'vegetable': Icons.eco,
    'produce': Icons.local_florist,
    'grocery': Icons.shopping_basket,
    'jewelry': Icons.diamond,
    'jewellery': Icons.diamond,
    'auto_parts': Icons.car_repair,
    'autoparts': Icons.car_repair,
    'book': Icons.menu_book,
    'petrol': Icons.local_gas_station,
    'food': Icons.restaurant,
    'restaurant': Icons.restaurant,
    'default': Icons.inventory_2,
  };

  static const Map<String, Color> categoryColorMap = {
    'laptop': Color(0xFF1976D2),
    'computer': Color(0xFF3B82F6),
    'mobile': Color(0xFF06B6D4),
    'clothing': Color(0xFFDB2777),
    'shirt': Color(0xFFDB2777),
    'tools': Color(0xFF424242),
    'hardware': Color(0xFF424242),
    'medicine': Color(0xFFE91E63),
    'pharmacy': Color(0xFFE91E63),
    'vegetable': Color(0xFF4CAF50),
    'produce': Color(0xFF4CAF50),
    'grocery': Color(0xFF388E3C),
    'jewelry': Color(0xFFFFD700),
    'jewellery': Color(0xFFFFD700),
    'auto_parts': Color(0xFF616161),
    'autoparts': Color(0xFF616161),
    'book': Color(0xFF8B4513),
    'petrol': Color(0xFFFF6F00),
    'food': Color(0xFFFF6F00),
    'restaurant': Color(0xFFFF6F00),
    'default': Color(0xFF9E9E9E),
  };

  // ── Input decoration factory ──────────────────────────────────────────────
  static InputDecoration compactInput({
    String? hint,
    String? label,
    Widget? suffix,
    bool isDense = true,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      hintStyle: const TextStyle(color: textSecondary, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      isDense: isDense,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }
}
