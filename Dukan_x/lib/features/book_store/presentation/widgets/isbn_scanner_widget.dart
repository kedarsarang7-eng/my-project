import 'package:flutter/material.dart';

// NOTE: A canonical ISBN scanner also exists at barcode/widgets/isbn_scanner_widget.dart.
// This local variant is kept because it carries bookstore-specific UI styling.
// ISBN validation is handled by BookStoreBusinessRules.isValidIsbn (the single
// authoritative validator).

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
}
