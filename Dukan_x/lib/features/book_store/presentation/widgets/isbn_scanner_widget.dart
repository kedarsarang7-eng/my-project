import 'package:flutter/material.dart';

// NOTE: A canonical ISBN scanner also exists at barcode/widgets/isbn_scanner_widget.dart.
// This local variant is kept because it carries bookstore-specific UI styling and
// static ISBN validation helpers. Do not delete.

/// ISBN Barcode Scanner Input Widget (Book Store UI variant)
///
/// Dedicated scanner input that:
/// 1. Auto-focuses for quick ISBN scanning
/// 2. Validates ISBN-10 / ISBN-13 format
/// 3. Triggers callback on Enter or valid ISBN detected
///
/// Data flow: Barcode Scanner → ISBN TextField → onIsbnScanned callback → POS cart
class IsbnScannerWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color accent;
  final ValueChanged<String> onIsbnScanned;

  const IsbnScannerWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.accent,
    required this.onIsbnScanned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Scan ISBN barcode or type ISBN...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.grey.shade400,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.qr_code_scanner_rounded,
            color: accent,
            size: 20,
          ),
          suffixIcon: IconButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onIsbnScanned(controller.text.trim());
              }
            },
            icon: Icon(Icons.arrow_forward_rounded, color: accent, size: 20),
            tooltip: 'Add book',
          ),
          filled: true,
          fillColor: isDark
              ? accent.withValues(alpha: 0.06)
              : accent.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            onIsbnScanned(value.trim());
          }
        },
      ),
    );
  }

  /// Validates ISBN-10 or ISBN-13 format
  static bool isValidIsbn(String isbn) {
    final cleaned = isbn.replaceAll(RegExp(r'[-\s]'), '');
    if (cleaned.length == 10) return _isValidIsbn10(cleaned);
    if (cleaned.length == 13) return _isValidIsbn13(cleaned);
    return false;
  }

  static bool _isValidIsbn10(String isbn) {
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      final digit = int.tryParse(isbn[i]);
      if (digit == null) return false;
      sum += digit * (10 - i);
    }
    final last = isbn[9].toUpperCase() == 'X' ? 10 : int.tryParse(isbn[9]);
    if (last == null) return false;
    sum += last;
    return sum % 11 == 0;
  }

  static bool _isValidIsbn13(String isbn) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.tryParse(isbn[i]);
      if (digit == null) return false;
      sum += digit * (i.isEven ? 1 : 3);
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.tryParse(isbn[12]);
  }
}
