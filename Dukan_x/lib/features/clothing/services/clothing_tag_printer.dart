// ============================================================================
// CLOTHING TAG PRINTER SERVICE
// ============================================================================
// Prints one price-tag/barcode label per selected variant via the existing
// Print_Infrastructure (BarcodeLabelGenerator + Printing.layoutPdf).
//
// Requirements: 12.6, 12.7
// - One tag rendered per selected variant.
// - A print failure names the affected variant and leaves its record unchanged.
// ============================================================================

import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../../barcode/widgets/barcode_label_printer.dart';
import '../data/variant_repository.dart';

/// Result of a variant tag print attempt.
class VariantPrintResult {
  /// Variant IDs that failed to print.
  final List<String> failedIds;

  /// Human-readable descriptions of each failure (variant name → error).
  final Map<String, String> failureDetails;

  /// Number of variants that printed successfully.
  final int successCount;

  VariantPrintResult({
    required this.failedIds,
    required this.failureDetails,
    required this.successCount,
  });

  bool get allSucceeded => failedIds.isEmpty;
}

/// Service that prints one price-tag/barcode per selected clothing variant.
///
/// Uses the existing [BarcodeLabelGenerator] to render labels as PDF and
/// [Printing.layoutPdf] to send them to the printer.
///
/// On failure for a specific variant, names the variant (color/size/sku) in
/// the error detail and leaves its record unchanged (Requirement 12.7).
class ClothingTagPrinter {
  /// The label format to use. Defaults to [LabelFormat.priceTag] which is the
  /// most appropriate for clothing variant tags (compact price + barcode).
  final LabelFormat labelFormat;

  /// Optional product name to include on labels. If null, uses
  /// "Variant: {color}/{size}" as the product name.
  final String? productName;

  const ClothingTagPrinter({
    this.labelFormat = LabelFormat.priceTag,
    this.productName,
  });

  /// Prints one price-tag/barcode per selected variant.
  ///
  /// Returns a [VariantPrintResult] containing:
  /// - [failedIds]: variant IDs that could not be printed
  /// - [failureDetails]: mapping of variant descriptors to error messages
  /// - [successCount]: count of successfully printed variants
  ///
  /// Each variant is printed independently so a failure for one does not
  /// prevent the others from printing. A variant's record is never modified
  /// by a print failure (Requirement 12.7).
  Future<VariantPrintResult> printVariantTags(
    List<VariantItem> variants,
  ) async {
    final failedIds = <String>[];
    final failureDetails = <String, String>{};
    int successCount = 0;

    for (final variant in variants) {
      try {
        await _printSingleTag(variant);
        successCount++;
      } catch (e) {
        failedIds.add(variant.id);
        final descriptor = _variantDescriptor(variant);
        failureDetails[descriptor] = e.toString();
      }
    }

    return VariantPrintResult(
      failedIds: failedIds,
      failureDetails: failureDetails,
      successCount: successCount,
    );
  }

  /// Renders and prints a single price-tag for one variant.
  ///
  /// The tag includes:
  /// - Product name (or variant color/size if no product name supplied)
  /// - Barcode (rendered as EAN-13, EAN-8, UPC-A, or Code128 depending on data)
  /// - Price (formatted from integer Paise to ₹ display)
  /// - Size and color info
  Future<void> _printSingleTag(VariantItem variant) async {
    final displayName =
        productName ?? '${variant.color} / ${variant.size}'.trim();

    // Build the label data. Price is stored as integer Paise; BarcodeLabelData
    // expects a double for display, so we convert priceCents → rupees.
    final labelData = BarcodeLabelData(
      productName: displayName.isEmpty ? 'Variant' : displayName,
      barcode: variant.barcode.isNotEmpty ? variant.barcode : variant.sku,
      price: variant.priceCents / 100.0,
      unit: 'Size: ${variant.size}',
      quantity: 1,
    );

    // Skip if no printable barcode data
    if (labelData.barcode.isEmpty) {
      throw Exception(
        'No barcode or SKU available for variant '
        '${_variantDescriptor(variant)}',
      );
    }

    // Generate the PDF for this single label
    final Uint8List pdfBytes = await BarcodeLabelGenerator.generateLabelsPdf(
      labels: [labelData],
      format: labelFormat,
    );

    // Send to printer via the standard printing infrastructure
    await Printing.layoutPdf(
      onLayout: (_) => pdfBytes,
      name: 'Clothing Tag - ${_variantDescriptor(variant)}',
    );
  }

  /// Returns a human-readable descriptor for a variant, used in error messages
  /// to name the affected variant (Requirement 12.7).
  String _variantDescriptor(VariantItem variant) {
    final parts = <String>[];
    if (variant.color.isNotEmpty) parts.add(variant.color);
    if (variant.size.isNotEmpty) parts.add(variant.size);
    if (variant.sku.isNotEmpty) parts.add('SKU:${variant.sku}');
    if (parts.isEmpty) parts.add('id:${variant.id}');
    return parts.join(' / ');
  }
}
