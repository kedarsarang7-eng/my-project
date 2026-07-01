// Adaptive PDF Layouts for Business-Type Specific Invoice Generation
// Configures column headers, widths, and special sections per business type
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:pdf/widgets.dart' as pw;

import '../billing/business_type_config.dart';

/// Defines column configuration for invoice table
class InvoiceColumn {
  final String header;
  final double widthFlex;
  final pw.Alignment alignment;
  final bool showInPdf;

  const InvoiceColumn({
    required this.header,
    this.widthFlex = 1.0,
    this.alignment = pw.Alignment.centerLeft,
    this.showInPdf = true,
  });
}

/// Layout configuration for a specific business type
class AdaptivePdfLayout {
  final BusinessType businessType;
  final List<InvoiceColumn> columns;
  final List<String> specialSections;
  final String footerNote;
  final bool showHsnColumn;
  final bool showBatchColumn;
  final bool showExpiryColumn;
  final bool showWarrantyColumn;
  final bool showSerialColumn;
  final bool showSizeColumn;
  final bool showColorColumn;
  final bool showTableColumn;
  final bool showLaborColumn;
  final bool showPartsColumn;

  const AdaptivePdfLayout({
    required this.businessType,
    required this.columns,
    this.specialSections = const [],
    this.footerNote = '',
    this.showHsnColumn = false,
    this.showBatchColumn = false,
    this.showExpiryColumn = false,
    this.showWarrantyColumn = false,
    this.showSerialColumn = false,
    this.showSizeColumn = false,
    this.showColorColumn = false,
    this.showTableColumn = false,
    this.showLaborColumn = false,
    this.showPartsColumn = false,
  });
}

/// Registry of PDF layouts per business type
class AdaptivePdfLayoutRegistry {
  static const Map<BusinessType, AdaptivePdfLayout> _layouts = {
    // =========================================================
    // 🛒 GENERAL STORE - Simple columns
    // =========================================================
    BusinessType.grocery: AdaptivePdfLayout(
      businessType: BusinessType.grocery,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Item', widthFlex: 3.0),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.8,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Unit',
          widthFlex: 0.6,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Rate',
          widthFlex: 1.0,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 1.2,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      footerNote: 'Thank you for your purchase!',
    ),

    // =========================================================
    // 🍽️ RESTAURANT - Table info, no GST columns
    // =========================================================
    BusinessType.restaurant: AdaptivePdfLayout(
      businessType: BusinessType.restaurant,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Dish', widthFlex: 3.0),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.6,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Type',
          widthFlex: 0.6,
          alignment: pw.Alignment.center,
        ), // Half/Full
        InvoiceColumn(
          header: 'Rate',
          widthFlex: 1.0,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 1.2,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showTableColumn: true,
      specialSections: ['serviceCharge'],
      footerNote: 'Thank you for dining with us!',
    ),

    // =========================================================
    // 💊 PHARMACY - Batch, Expiry critical
    // =========================================================
    BusinessType.pharmacy: AdaptivePdfLayout(
      businessType: BusinessType.pharmacy,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Medicine', widthFlex: 2.5),
        InvoiceColumn(
          header: 'Batch',
          widthFlex: 0.8,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Expiry',
          widthFlex: 0.7,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.5,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'MRP',
          widthFlex: 0.8,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 1.0,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showBatchColumn: true,
      showExpiryColumn: true,
      specialSections: ['expiryWarning'],
      footerNote:
          'Always follow dosage as prescribed. Check expiry before use.',
    ),

    // =========================================================
    // 👕 CLOTHING - Size, Color
    // =========================================================
    BusinessType.clothing: AdaptivePdfLayout(
      businessType: BusinessType.clothing,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Item', widthFlex: 2.5),
        InvoiceColumn(
          header: 'Size',
          widthFlex: 0.5,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Color',
          widthFlex: 0.7,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.5,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Price',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 1.0,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showSizeColumn: true,
      showColorColumn: true,
      footerNote: 'Exchange/Return within 7 days with original tags.',
    ),

    // =========================================================
    // 🧰 HARDWARE - HSN, Weight
    // =========================================================
    BusinessType.hardware: AdaptivePdfLayout(
      businessType: BusinessType.hardware,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Item', widthFlex: 2.2),
        InvoiceColumn(
          header: 'HSN',
          widthFlex: 0.7,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.5,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Unit',
          widthFlex: 0.5,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Rate',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'GST%',
          widthFlex: 0.5,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 1.0,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showHsnColumn: true,
      footerNote: 'Goods once sold will not be taken back.',
    ),

    // =========================================================
    // 📱 ELECTRONICS - IMEI, Warranty
    // =========================================================
    BusinessType.electronics: AdaptivePdfLayout(
      businessType: BusinessType.electronics,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Product', widthFlex: 2.0),
        InvoiceColumn(
          header: 'IMEI/Serial',
          widthFlex: 1.2,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Warranty',
          widthFlex: 0.6,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.4,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'MRP',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 1.0,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showSerialColumn: true,
      showWarrantyColumn: true,
      specialSections: ['warrantyTerms'],
      footerNote:
          'Warranty valid only with original invoice. No warranty on physical damage.',
    ),

    // =========================================================
    // 🧾 SERVICE - Labor, Parts breakdown
    // =========================================================
    BusinessType.service: AdaptivePdfLayout(
      businessType: BusinessType.service,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Service Description', widthFlex: 2.5),
        InvoiceColumn(
          header: 'Labor',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Parts',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Total',
          widthFlex: 1.0,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showLaborColumn: true,
      showPartsColumn: true,
      specialSections: ['serviceNotes'],
      footerNote: 'Service warranty valid for 30 days from invoice date.',
    ),

    // =========================================================
    // 🥬 VEGETABLE BROKER - Weight, Commission, Market Fee
    // =========================================================
    BusinessType.vegetablesBroker: AdaptivePdfLayout(
      businessType: BusinessType.vegetablesBroker,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Item', widthFlex: 1.8),
        InvoiceColumn(
          header: 'Lot',
          widthFlex: 0.6,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Gross',
          widthFlex: 0.6,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Tare',
          widthFlex: 0.5,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Net',
          widthFlex: 0.6,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Rate',
          widthFlex: 0.7,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Comm.',
          widthFlex: 0.6,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Mkt Fee',
          widthFlex: 0.6,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      footerNote:
          'Weights as per electronic scale. Commission rates as agreed.',
    ),

    // =========================================================
    // 📱 MOBILE SHOP - IMEI, Warranty (dedicated)
    // =========================================================
    BusinessType.mobileShop: AdaptivePdfLayout(
      businessType: BusinessType.mobileShop,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Product', widthFlex: 1.8),
        InvoiceColumn(
          header: 'IMEI',
          widthFlex: 1.4,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Warranty',
          widthFlex: 0.6,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.4,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'MRP',
          widthFlex: 0.8,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showSerialColumn: true,
      showWarrantyColumn: true,
      specialSections: ['warrantyTerms'],
      footerNote:
          'IMEI/Serial required for warranty claims. Keep original invoice.',
    ),

    // =========================================================
    // 💻 COMPUTER SHOP - Serial, Warranty, Specs
    // =========================================================
    BusinessType.computerShop: AdaptivePdfLayout(
      businessType: BusinessType.computerShop,
      columns: [
        InvoiceColumn(
          header: '#',
          widthFlex: 0.3,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(header: 'Product', widthFlex: 2.0),
        InvoiceColumn(
          header: 'Serial No',
          widthFlex: 1.2,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Warranty',
          widthFlex: 0.5,
          alignment: pw.Alignment.center,
        ),
        InvoiceColumn(
          header: 'Qty',
          widthFlex: 0.4,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Rate',
          widthFlex: 0.8,
          alignment: pw.Alignment.centerRight,
        ),
        InvoiceColumn(
          header: 'Amount',
          widthFlex: 0.9,
          alignment: pw.Alignment.centerRight,
        ),
      ],
      showSerialColumn: true,
      showWarrantyColumn: true,
      specialSections: ['warrantyTerms'],
      footerNote:
          'Software warranty excluded. Hardware warranty as per manufacturer.',
    ),
  };

  /// Get layout for a business type
  static AdaptivePdfLayout getLayout(BusinessType type) {
    return _layouts[type] ?? _layouts[BusinessType.grocery]!;
  }

  /// Get layout by string name
  static AdaptivePdfLayout getLayoutByName(String typeName) {
    final type = BusinessType.values.firstWhere(
      (t) => t.name == typeName || t.toString() == typeName,
      orElse: () => BusinessType.grocery,
    );
    return getLayout(type);
  }

  /// Get column headers as list
  static List<String> getHeaders(BusinessType type) {
    return getLayout(type).columns.map((c) => c.header).toList();
  }

  /// Get column flex widths
  static List<double> getColumnWidths(BusinessType type) {
    return getLayout(type).columns.map((c) => c.widthFlex).toList();
  }
}

/// Helper to build adaptive table row based on business type
class AdaptiveTableRowBuilder {
  /// Build row data based on business type
  static List<String> buildRowData({
    required BusinessType businessType,
    required int index,
    required String itemName,
    required double quantity,
    required String unit,
    required double price,
    required double amount,
    // Business-specific
    String? batchNo,
    DateTime? expiryDate,
    String? serialNo,
    int? warrantyMonths,
    String? size,
    String? color,
    String? tableNo,
    bool? isHalf,
    double? laborCharge,
    double? partsCharge,
    String? hsn,
    double? gstRate,
    // Vegetable Broker specific
    String? lotId,
    double? grossWeight,
    double? tareWeight,
    double? netWeight,
    double? commission,
    double? marketFee,
  }) {
    final layout = AdaptivePdfLayoutRegistry.getLayout(businessType);
    final List<String> row = [];

    for (final col in layout.columns) {
      switch (col.header) {
        case '#':
          row.add('${index + 1}');
          break;
        case 'Item':
        case 'Dish':
        case 'Medicine':
        case 'Product':
        case 'Service Description':
          row.add(itemName);
          break;
        case 'Qty':
          row.add(_formatQty(quantity));
          break;
        case 'Unit':
          row.add(unit);
          break;
        case 'Rate':
        case 'Price':
        case 'MRP':
          row.add('₹${price.toStringAsFixed(2)}');
          break;
        case 'Amount':
        case 'Total':
          row.add('₹${amount.toStringAsFixed(2)}');
          break;
        case 'Batch':
          row.add(batchNo ?? '-');
          break;
        case 'Expiry':
          row.add(
            expiryDate != null
                ? '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year % 100}'
                : '-',
          );
          break;
        case 'IMEI/Serial':
        case 'IMEI':
        case 'Serial No':
          row.add(serialNo ?? '-');
          break;
        case 'Warranty':
          row.add(warrantyMonths != null ? '${warrantyMonths}M' : '-');
          break;
        case 'Size':
          row.add(size ?? '-');
          break;
        case 'Color':
          row.add(color ?? '-');
          break;
        case 'Type': // Half/Full for restaurant
          row.add(isHalf == true ? 'Half' : 'Full');
          break;
        case 'Labor':
          row.add('₹${(laborCharge ?? 0).toStringAsFixed(0)}');
          break;
        case 'Parts':
          row.add('₹${(partsCharge ?? 0).toStringAsFixed(0)}');
          break;
        case 'HSN':
          row.add(hsn ?? '-');
          break;
        case 'GST%':
          row.add(gstRate != null ? '${gstRate.toStringAsFixed(0)}%' : '-');
          break;
        // Vegetable Broker specific columns
        case 'Lot':
          row.add(lotId ?? '-');
          break;
        case 'Gross':
          row.add(
            grossWeight != null ? '${grossWeight.toStringAsFixed(2)} kg' : '-',
          );
          break;
        case 'Tare':
          row.add(
            tareWeight != null ? '${tareWeight.toStringAsFixed(2)} kg' : '-',
          );
          break;
        case 'Net':
          row.add(
            netWeight != null ? '${netWeight.toStringAsFixed(2)} kg' : '-',
          );
          break;
        case 'Comm.':
          row.add(
            commission != null ? '₹${commission.toStringAsFixed(0)}' : '-',
          );
          break;
        case 'Mkt Fee':
          row.add(marketFee != null ? '₹${marketFee.toStringAsFixed(0)}' : '-');
          break;
        default:
          row.add('-');
      }
    }

    return row;
  }

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }
}
