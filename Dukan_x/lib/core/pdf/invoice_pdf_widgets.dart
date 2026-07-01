// Invoice PDF Widgets - Reusable PDF Widget Components
// Clean, modular widgets for professional invoice generation
//
// Created: 2024-12-26
// Author: DukanX Team

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'invoice_pdf_theme.dart';
import 'amount_to_words.dart';
import 'invoice_models.dart';
import 'invoice_column_model.dart';
import '../../../services/invoice_pdf_service.dart' show InvoiceLanguage;
import '../di/service_locator.dart';
import '../services/currency_service.dart';
import '../../features/pharmacy/utils/drug_license.dart';

/// Reusable widgets for invoice PDF generation
class InvoicePdfWidgets {
  final InvoicePdfTheme theme;
  final Map<String, String> labels;
  final InvoiceLanguage language;

  // Currency formatter
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: sl<CurrencyService>().symbol,
    decimalDigits: 2,
  );

  InvoicePdfWidgets({
    required this.theme,
    required this.labels,
    this.language = InvoiceLanguage.english,
  });

  /// Build invoice header with shop details
  pw.Widget buildHeader({
    required String shopName,
    required String ownerName,
    required String address,
    required String mobile,
    String? email,
    String? gstin,
    String? fssaiNumber,
    String? drugLicenseNumber,
    String? tagline,
    Uint8List? logoImage,
    Uint8List? avatarImage,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Row with Logo/Avatar and Shop Name
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo (if available)
            if (logoImage != null)
              pw.Container(
                height: 60,
                width: 60,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(
                  pw.MemoryImage(logoImage),
                  fit: pw.BoxFit.contain,
                ),
              )
            else if (avatarImage != null)
              pw.Container(
                height: 50,
                width: 50,
                margin: const pw.EdgeInsets.only(right: 12),
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: theme.primaryColor, width: 1),
                ),
                child: pw.ClipOval(
                  child: pw.Image(
                    pw.MemoryImage(avatarImage),
                    fit: pw.BoxFit.cover,
                  ),
                ),
              ),
            // Shop Name & Tagline
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    _truncateText(shopName.toUpperCase(), 40),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: theme.primaryColor,
                      letterSpacing: 1.2,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (tagline != null && tagline.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      tagline,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: theme.textGray,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        // Owner Name
        pw.Text(
          '${labels['proprietor']}: $ownerName',
          style: pw.TextStyle(fontSize: 10, color: theme.textGray),
        ),
        pw.SizedBox(height: 4),

        // Address
        pw.Text(
          _truncateText(address, 80),
          style: pw.TextStyle(fontSize: 10, color: theme.textDark),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),

        // Contact Details Row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              '${labels['mobile']}: $mobile',
              style: pw.TextStyle(fontSize: 10, color: theme.textDark),
            ),
            if (email != null && email.isNotEmpty) ...[
              pw.Text('  |  ', style: pw.TextStyle(color: theme.textGray)),
              pw.Text(
                _truncateText(email, 30),
                style: pw.TextStyle(fontSize: 10, color: theme.textDark),
              ),
            ],
          ],
        ),

        // GSTIN Badge
        if (gstin != null && gstin.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: pw.BoxDecoration(
              color: theme.primaryLight,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'GSTIN: $gstin',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],

        // FSSAI Badge (for food businesses)
        if (fssaiNumber != null && fssaiNumber.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'FSSAI: $fssaiNumber',
            style: pw.TextStyle(fontSize: 9, color: theme.textGray),
          ),
        ],

        // Drug License Number (pharmacy invoices, R14.2). Rendered only when a
        // value is configured; omitted entirely when absent (R14.3). The
        // include/omit decision and rendered text are owned by
        // DrugLicense.headerLine so the template and tests share one rule.
        if (DrugLicense.headerLine(drugLicenseNumber) != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            DrugLicense.headerLine(drugLicenseNumber)!,
            style: pw.TextStyle(fontSize: 9, color: theme.textGray),
          ),
        ],
      ],
    );
  }

  /// Build invoice info box (number, date, status, payment mode)
  pw.Widget buildInvoiceInfoBox({
    required String invoiceNumber,
    required DateTime invoiceDate,
    DateTime? dueDate,
    required InvoiceStatus status,
    required PaymentMode paymentMode,
    required bool isGstBill,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: theme.primaryLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: theme.primaryColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Invoice Title
          pw.Text(
            isGstBill ? labels['taxInvoice']! : labels['invoice']!,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          pw.SizedBox(height: 10),

          // Invoice Number
          _buildInfoRow(labels['invoiceNo']!, invoiceNumber),
          pw.SizedBox(height: 4),

          // Date & Time
          _buildInfoRow(labels['date']!, dateFormat.format(invoiceDate)),
          pw.SizedBox(height: 4),
          _buildInfoRow('Time', timeFormat.format(invoiceDate)),

          // Due Date
          if (dueDate != null) ...[
            pw.SizedBox(height: 4),
            _buildInfoRow(labels['dueDate']!, dateFormat.format(dueDate)),
          ],
          pw.SizedBox(height: 8),

          // Status Badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: status.getColor(theme),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              status.displayText,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 6),

          // Payment Mode
          pw.Text(
            'Payment: ${paymentMode.displayText}',
            style: pw.TextStyle(fontSize: 9, color: theme.textGray),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(fontSize: 10, color: theme.textGray),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: theme.textDark,
          ),
        ),
      ],
    );
  }

  /// Build customer section (Bill To)
  pw.Widget buildCustomerSection({
    required String name,
    required String mobile,
    String? address,
    String? gstin,
  }) {
    // Handle Walk-in Customer
    final displayName = name.isEmpty ? 'Walk-in Customer' : name;
    final displayMobile = mobile.isEmpty ? '-' : mobile;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: theme.borderColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            labels['billedTo']!,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _truncateText(displayName, 35),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: theme.textDark,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${labels['mobile']}: $displayMobile',
            style: pw.TextStyle(fontSize: 10, color: theme.textDark),
          ),
          if (address != null && address.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              _truncateText(address, 60),
              style: pw.TextStyle(fontSize: 10, color: theme.textGray),
            ),
          ],
          if (gstin != null && gstin.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'GSTIN: $gstin',
              style: pw.TextStyle(fontSize: 10, color: theme.textDark),
            ),
          ],
        ],
      ),
    );
  }

  /// Build items table (handles multi-page automatically with MultiPage)
  pw.Widget buildItemsTable({
    required List<ItemRowData> items,
    required bool showTax,
  }) {
    final headers = [
      labels['slNo']!,
      labels['description']!,
      labels['qty']!,
      labels['unit']!,
      labels['rate']!,
      if (showTax) labels['tax']!,
      labels['discount'] ?? 'Disc',
      labels['amount']!,
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: theme.borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.4), // Sl No
        1: const pw.FlexColumnWidth(2.5), // Description
        2: const pw.FlexColumnWidth(0.7), // Qty
        3: const pw.FlexColumnWidth(0.6), // Unit
        4: const pw.FlexColumnWidth(1.0), // Rate
        if (showTax) 5: const pw.FlexColumnWidth(0.6), // Tax
        showTax ? 6 : 5: const pw.FlexColumnWidth(0.7), // Discount
        showTax ? 7 : 6: const pw.FlexColumnWidth(1.0), // Amount
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: theme.primaryColor),
          children: headers
              .map(
                (h) => pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        // Data Rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isEven = index % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : theme.primaryLight,
            ),
            children: [
              _tableCell('${index + 1}'),
              _tableCell(
                _truncateText(item.name, 40),
                align: pw.Alignment.centerLeft,
              ),
              _tableCell(item.quantity),
              _tableCell(item.unit),
              _tableCell(
                _currencyFormat.format(item.rate),
                align: pw.Alignment.centerRight,
              ),
              if (showTax)
                _tableCell(
                  item.taxPercent != null ? '${item.taxPercent}%' : '-',
                ),
              _tableCell(
                item.discount != null && item.discount! > 0
                    ? _currencyFormat.format(item.discount!)
                    : '-',
                align: pw.Alignment.centerRight,
              ),
              _tableCell(
                _currencyFormat.format(item.amount),
                align: pw.Alignment.centerRight,
                bold: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Build dynamic items table based on schema
  pw.Widget buildDynamicItemsTable({
    required List<EnhancedInvoiceItem> items,
    required List<InvoiceColumn> columns,
  }) {
    // 1. Build Headers
    final headers = columns.map((col) {
      String label = labels[col.labelIndex] ?? col.fallbackLabel;
      return _tableHeaderCell(label, alignment: col.alignment);
    }).toList();

    // 2. Build Column Widths
    final Map<int, pw.TableColumnWidth> columnWidths = {};
    for (int i = 0; i < columns.length; i++) {
      columnWidths[i] = pw.FlexColumnWidth(columns[i].flex);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: theme.borderColor, width: 0.5),
      columnWidths: columnWidths,
      children: [
        // Header Row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: theme.primaryColor),
          children: headers,
        ),
        // Data Rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isEven = index % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : theme.primaryLight,
            ),
            children: columns.map((col) {
              if (col.key == 'sno') {
                return _tableCell('${index + 1}', align: col.alignment);
              }
              return _tableCell(
                col.valueExtractor(item),
                align: col.alignment,
                bold: col.key == 'amount', // Make amount bold
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  pw.Widget _tableHeaderCell(
    String text, {
    pw.Alignment alignment = pw.Alignment.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignment,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    pw.Alignment align = pw.Alignment.center,
    bool bold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: theme.textDark,
        ),
      ),
    );
  }

  /// Build totals section (right-aligned)
  pw.Widget buildTotalsSection({
    required double subtotal,
    required double discount,
    double? cgst,
    double? sgst,
    double? igst,
    required double taxAmount,
    double? roundOff,
    required double grandTotal,
    required bool showTax,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: theme.borderColor),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _totalRow(labels['subtotal']!, subtotal),
              if (discount > 0) ...[
                pw.SizedBox(height: 4),
                _totalRow(labels['discount']!, -discount, isNegative: true),
              ],
              if (showTax && taxAmount > 0) ...[
                pw.SizedBox(height: 4),
                if (cgst != null && cgst > 0) _totalRow('CGST', cgst),
                if (sgst != null && sgst > 0) ...[
                  pw.SizedBox(height: 4),
                  _totalRow('SGST', sgst),
                ],
                if (igst != null && igst > 0) ...[
                  pw.SizedBox(height: 4),
                  _totalRow('IGST', igst),
                ],
              ],
              if (roundOff != null && roundOff != 0) ...[
                pw.SizedBox(height: 4),
                _totalRow('Round Off', roundOff, isNegative: roundOff < 0),
              ],
              pw.SizedBox(height: 6),
              pw.Divider(color: theme.borderColor),
              pw.SizedBox(height: 6),
              _totalRow(
                labels['grandTotal']!,
                grandTotal,
                isBold: true,
                isHighlight: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isNegative = false,
    bool isHighlight = false,
  }) {
    return pw.Container(
      padding: isHighlight ? const pw.EdgeInsets.all(8) : pw.EdgeInsets.zero,
      decoration: isHighlight
          ? pw.BoxDecoration(
              color: theme.primaryLight,
              borderRadius: pw.BorderRadius.circular(4),
            )
          : null,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isHighlight ? 11 : 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHighlight ? theme.primaryColor : theme.textDark,
            ),
          ),
          pw.Text(
            '${isNegative ? "- " : ""}${_currencyFormat.format(amount.abs())}',
            style: pw.TextStyle(
              fontSize: isHighlight ? 13 : 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isNegative
                  ? theme.errorColor
                  : (isHighlight ? theme.primaryColor : theme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Build amount in words section
  pw.Widget buildAmountInWords(double amount) {
    final words = AmountToWords.convert(amount, language);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF3F4F6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '${labels['amountInWords']}: ',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: theme.textGray,
              ),
            ),
            pw.TextSpan(
              text: words,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.normal,
                color: theme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build notes & terms section
  pw.Widget buildNotesSection({String? notes, String? terms}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (notes != null && notes.isNotEmpty) ...[
          pw.Text(
            labels['notes']!,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: theme.textDark,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            notes,
            style: pw.TextStyle(fontSize: 9, color: theme.textGray),
          ),
          pw.SizedBox(height: 10),
        ],
        if (terms != null && terms.isNotEmpty) ...[
          pw.Text(
            labels['termsConditions']!,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: theme.textDark,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            terms,
            style: pw.TextStyle(fontSize: 9, color: theme.textGray),
          ),
        ],
      ],
    );
  }

  /// Build signature section with optional stamp
  pw.Widget buildSignatureSection({
    Uint8List? signatureImage,
    Uint8List? stampImage,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        // Stamp (if available)
        if (stampImage != null)
          pw.Container(
            height: 50,
            width: 50,
            margin: const pw.EdgeInsets.only(right: 20),
            child: pw.Image(pw.MemoryImage(stampImage), fit: pw.BoxFit.contain),
          ),
        // Signature
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (signatureImage != null)
              pw.Container(
                height: 45,
                width: 100,
                child: pw.Image(
                  pw.MemoryImage(signatureImage),
                  fit: pw.BoxFit.contain,
                ),
              )
            else
              pw.Container(
                height: 45,
                width: 100,
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: theme.textDark),
                  ),
                ),
              ),
            pw.SizedBox(height: 4),
            pw.Text(
              labels['authorizedSignature']!,
              style: pw.TextStyle(fontSize: 9, color: theme.textGray),
            ),
          ],
        ),
      ],
    );
  }

  /// Build footer with thank you, return policy, and page number
  pw.Widget buildFooter({
    String? returnPolicy,
    int? pageNumber,
    int? totalPages,
  }) {
    return pw.Column(
      children: [
        pw.Divider(color: theme.borderColor),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            labels['thankYou']!,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
        if (returnPolicy != null && returnPolicy.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              returnPolicy,
              style: pw.TextStyle(fontSize: 8, color: theme.textGray),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              labels['computerGenerated']!,
              style: pw.TextStyle(fontSize: 8, color: theme.textGray),
            ),
            if (pageNumber != null && totalPages != null)
              pw.Text(
                'Page $pageNumber of $totalPages',
                style: pw.TextStyle(fontSize: 8, color: theme.textGray),
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Powered by DukanX',
            style: pw.TextStyle(
              fontSize: 6,
              color: PdfColors.grey400,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Build QR code for UPI payment
  pw.Widget buildQrCode({
    required String upiId,
    required String shopName,
    required double amount,
  }) {
    final upiUri = 'upi://pay?pa=$upiId&pn=$shopName&am=$amount&cu=INR';

    return pw.Container(
      width: 70,
      height: 70,
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: upiUri,
        drawText: false,
      ),
    );
  }

  // === HELPER METHODS ===

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}

/// Data class for items table row
class ItemRowData {
  final String name;
  final String quantity;
  final String unit;
  final double rate;
  final double? taxPercent;
  final double? discount;
  final double amount;

  ItemRowData({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.rate,
    this.taxPercent,
    this.discount,
    required this.amount,
  });
}
