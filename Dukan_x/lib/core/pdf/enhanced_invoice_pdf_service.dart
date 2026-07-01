// Enhanced Invoice PDF Service - Production-grade PDF Generation
// Supports multi-page, business-type themes, multi-language, and all edge cases
//
// Created: 2024-12-26
// Author: DukanX Team

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'invoice_pdf_theme.dart';
import 'invoice_pdf_widgets.dart';
import 'invoice_models.dart';
import 'invoice_column_model.dart';
import '../../models/bill.dart';
import '../../services/invoice_pdf_service.dart' show InvoiceLanguage;

/// Main Enhanced Invoice PDF Service
class EnhancedInvoicePdfService {
  static final EnhancedInvoicePdfService _instance =
      EnhancedInvoicePdfService._internal();
  factory EnhancedInvoicePdfService() => _instance;
  EnhancedInvoicePdfService._internal();

  /// Generate professional multi-page invoice PDF
  Future<Uint8List> generateInvoicePdf({
    required EnhancedInvoiceConfig config,
    required EnhancedInvoiceCustomer customer,
    required List<EnhancedInvoiceItem> items,
    required String invoiceNumber,
    required DateTime invoiceDate,
    DateTime? dueDate,
    double? additionalDiscount,
    String? notes,
    InvoiceStatus? status,
    PaymentMode? paymentMode,
  }) async {
    // Load fonts
    final regularFont = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final boldFont = await _loadFont('assets/fonts/NotoSans-Bold.ttf');

    pw.Font baseFont = pw.Font.helvetica();
    pw.Font baseBoldFont = pw.Font.helveticaBold();

    if (regularFont != null) baseFont = regularFont;
    if (boldFont != null) baseBoldFont = boldFont;

    // Get theme based on business type
    final theme = InvoicePdfTheme.fromBusinessType(config.businessType);

    // Get labels for language
    final labels = _getLabels(config.language);

    // Create widgets helper
    final widgets = InvoicePdfWidgets(
      theme: theme,
      labels: labels,
      language: config.language,
    );

    // Calculate totals
    double subtotal = items.fold(0, (sum, item) => sum + item.subtotal);
    double totalItemDiscount = items.fold(
      0,
      (sum, item) => sum + item.discount,
    );
    double totalDiscount = totalItemDiscount + (additionalDiscount ?? 0);
    double totalCgst = items.fold(0, (sum, item) => sum + (item.cgst ?? 0));
    double totalSgst = items.fold(0, (sum, item) => sum + (item.sgst ?? 0));
    double totalIgst = items.fold(0, (sum, item) => sum + (item.igst ?? 0));
    double totalTax = totalCgst + totalSgst + totalIgst;
    double taxableAmount = subtotal - totalDiscount;
    double grandTotalBeforeRound = taxableAmount + totalTax;

    // Calculate round-off
    double roundOff =
        grandTotalBeforeRound.roundToDouble() - grandTotalBeforeRound;
    double grandTotal = grandTotalBeforeRound + roundOff;

    // Determine status
    final invoiceStatus = status ?? InvoiceStatus.unpaid;
    final invoicePaymentMode = paymentMode ?? PaymentMode.cash;

    // Convert items to row data
    final List<ItemRowData> itemRows = items
        .map(
          (item) => ItemRowData(
            name: item.name,
            quantity: _formatQuantity(item.quantity),
            unit: item.unit,
            rate: item.unitPrice,
            taxPercent: item.taxPercent,
            discount: item.discount,
            amount: item.total,
          ),
        )
        .toList();

    // Create PDF document
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: baseBoldFont),
    );

    // Use MultiPage for automatic page handling
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        maxPages: 100, // Support up to 100 pages for very large invoices
        header: (pw.Context context) {
          // Only show header on first page
          if (context.pageNumber == 1) {
            return pw.SizedBox.shrink();
          }
          // Mini header for continuation pages
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  config.shopName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                pw.Text(
                  'Invoice #$invoiceNumber (Continued)',
                  style: pw.TextStyle(fontSize: 10, color: theme.textGray),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  labels['computerGenerated']!,
                  style: pw.TextStyle(fontSize: 8, color: theme.textGray),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: theme.textGray),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // ===== HEADER SECTION =====
            widgets.buildHeader(
              shopName: config.shopName,
              ownerName: config.ownerName,
              address: config.address,
              mobile: config.mobile,
              email: config.email,
              gstin: config.gstin,
              fssaiNumber: config.fssaiNumber,
              drugLicenseNumber: config.drugLicenseNumber,
              tagline: config.tagline,
              logoImage: config.logoImage,
              avatarImage: config.avatarImage,
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: theme.primaryColor, thickness: 2),
            pw.SizedBox(height: 16),

            // ===== INVOICE INFO + CUSTOMER ROW =====
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Customer Details
                pw.Expanded(
                  flex: 3,
                  child: widgets.buildCustomerSection(
                    name: customer.name,
                    mobile: customer.mobile,
                    address: customer.address,
                    gstin: customer.gstin,
                  ),
                ),
                pw.SizedBox(width: 16),
                // Right: Invoice Info + Optional QR
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    children: [
                      widgets.buildInvoiceInfoBox(
                        invoiceNumber: invoiceNumber,
                        invoiceDate: invoiceDate,
                        dueDate: dueDate,
                        status: invoiceStatus,
                        paymentMode: invoicePaymentMode,
                        isGstBill: config.isGstBill,
                      ),
                      // QR Code for UPI (if upiId provided)
                      if (config.upiId != null &&
                          config.upiId!.isNotEmpty &&
                          grandTotal > 0) ...[
                        pw.SizedBox(height: 10),
                        widgets.buildQrCode(
                          upiId: config.upiId!,
                          shopName: config.shopName,
                          amount: grandTotal,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ===== ITEMS TABLE =====
            if (config.version >= 2)
              widgets.buildDynamicItemsTable(
                items: items,
                columns: InvoiceSchemaResolver.getColumns(
                  config.businessType,
                  config.showTax,
                ),
              )
            else
              widgets.buildItemsTable(items: itemRows, showTax: config.showTax),
            pw.SizedBox(height: 16),

            // ===== TOTALS SECTION =====
            widgets.buildTotalsSection(
              subtotal: subtotal,
              discount: totalDiscount,
              cgst: config.showTax ? totalCgst : null,
              sgst: config.showTax ? totalSgst : null,
              igst: config.showTax ? totalIgst : null,
              taxAmount: totalTax,
              roundOff: roundOff.abs() > 0.001 ? roundOff : null,
              grandTotal: grandTotal,
              showTax: config.showTax,
            ),
            pw.SizedBox(height: 14),

            // ===== AMOUNT IN WORDS =====
            widgets.buildAmountInWords(grandTotal),
            pw.SizedBox(height: 16),

            // ===== NOTES / TERMS =====
            if (notes != null || config.termsAndConditions != null)
              widgets.buildNotesSection(
                notes: notes,
                terms: config.termsAndConditions,
              ),

            pw.Spacer(),

            // ===== SIGNATURE SECTION =====
            widgets.buildSignatureSection(
              signatureImage: config.signatureImage,
              stampImage: config.stampImage,
            ),
            pw.SizedBox(height: 12),

            // ===== FOOTER =====
            widgets.buildFooter(returnPolicy: config.returnPolicy),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate invoice from Bill model (convenience method)
  Future<Uint8List> generateFromBill({
    required Bill bill,
    required EnhancedInvoiceConfig config,
    String? notes,
  }) async {
    // Convert bill items
    final items = bill.items
        .map((item) => EnhancedInvoiceItem.fromBillItem(item))
        .toList();

    // Create customer
    final customer = EnhancedInvoiceCustomer.fromBill(bill);

    // Determine status
    InvoiceStatus status;
    if (bill.status == 'Paid') {
      status = InvoiceStatus.paid;
    } else if (bill.status == 'Partial') {
      status = InvoiceStatus.partial;
    } else {
      status = InvoiceStatus.unpaid;
    }

    // Determine payment mode
    PaymentMode paymentMode;
    switch (bill.paymentType.toLowerCase()) {
      case 'online':
      case 'upi':
        paymentMode = PaymentMode.upi;
        break;
      case 'card':
        paymentMode = PaymentMode.card;
        break;
      case 'credit':
        paymentMode = PaymentMode.credit;
        break;
      case 'mixed':
        paymentMode = PaymentMode.mixed;
        break;
      default:
        paymentMode = PaymentMode.cash;
    }

    return generateInvoicePdf(
      config: config,
      customer: customer,
      items: items,
      invoiceNumber: bill.invoiceNumber.isEmpty
          ? 'INV-${DateTime.now().millisecondsSinceEpoch}'
          : bill.invoiceNumber,
      invoiceDate: bill.date,
      additionalDiscount: bill.discountApplied,
      notes: notes,
      status: status,
      paymentMode: paymentMode,
    );
  }

  // ===== EXPORT METHODS =====

  /// Share invoice via platform share sheet
  Future<void> shareInvoice(
    Uint8List pdfBytes,
    String invoiceNumber, {
    String? paymentLink,
    String? message,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Invoice_$invoiceNumber.pdf');
    await file.writeAsBytes(pdfBytes);

    String shareText = message ?? 'Invoice #$invoiceNumber from DukanX';
    if (paymentLink != null) {
      shareText += "\n\nPAY NOW: $paymentLink";
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: shareText,
      subject: 'Invoice #$invoiceNumber',
    );
  }

  /// Print invoice directly
  Future<void> printInvoice(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice',
    );
  }

  /// Save invoice to downloads/documents
  Future<String?> saveInvoice(Uint8List pdfBytes, String invoiceNumber) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final invoicesDir = Directory('${directory.path}/Invoices');
      if (!await invoicesDir.exists()) {
        await invoicesDir.create(recursive: true);
      }
      final path = '${invoicesDir.path}/Invoice_$invoiceNumber.pdf';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      return path;
    } catch (e) {
      return null;
    }
  }

  /// Preview invoice (returns PDF for display)
  Future<Uint8List> previewInvoice({
    required EnhancedInvoiceConfig config,
    required EnhancedInvoiceCustomer customer,
    required List<EnhancedInvoiceItem> items,
    required String invoiceNumber,
    required DateTime invoiceDate,
  }) async {
    return generateInvoicePdf(
      config: config,
      customer: customer,
      items: items,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
    );
  }

  // ===== HELPER METHODS =====

  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }

  Future<pw.Font?> _loadFont(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.Font.ttf(data);
    } catch (e) {
      return null;
    }
  }

  Map<String, String> _getLabels(InvoiceLanguage language) {
    switch (language) {
      case InvoiceLanguage.hindi:
        return _hindiLabels;
      case InvoiceLanguage.marathi:
        return _marathiLabels;
      case InvoiceLanguage.gujarati:
        return _gujaratiLabels;
      case InvoiceLanguage.tamil:
        return _tamilLabels;
      case InvoiceLanguage.telugu:
        return _teluguLabels;
      case InvoiceLanguage.bengali:
        return _bengaliLabels;
      default:
        return _englishLabels;
    }
  }

  // ========== LANGUAGE LABELS ==========

  static const Map<String, String> _englishLabels = {
    'invoice': 'INVOICE',
    'taxInvoice': 'TAX INVOICE',
    'invoiceNo': 'Invoice No',
    'date': 'Date',
    'dueDate': 'Due Date',
    'billedTo': 'Billed To',
    'proprietor': 'Proprietor',
    'mobile': 'Mobile',
    'email': 'Email',
    'slNo': '#',
    'description': 'Description',
    'qty': 'Qty',
    'unit': 'Unit',
    'rate': 'Rate',
    'tax': 'Tax',
    'discount': 'Discount',
    'amount': 'Amount',
    'subtotal': 'Subtotal',
    'taxAmount': 'Tax Amount',
    'grandTotal': 'Grand Total',
    'amountInWords': 'Amount in Words',
    'notes': 'Notes',
    'termsConditions': 'Terms & Conditions',
    'authorizedSignature': 'Authorized Signature',
    'thankYou': 'Thank You for Your Business!',
    'computerGenerated': 'This is a computer-generated invoice',
  };

  static const Map<String, String> _hindiLabels = {
    'invoice': 'à¤¬à¤¿à¤²',
    'taxInvoice': 'à¤Ÿà¥ˆà¤•à¥à¤¸ à¤¬à¤¿à¤²',
    'invoiceNo': 'à¤¬à¤¿à¤² à¤¨à¤‚à¤¬à¤°',
    'date': 'à¤¦à¤¿à¤¨à¤¾à¤‚à¤•',
    'dueDate': 'à¤¦à¥‡à¤¯ à¤¤à¤¿à¤¥à¤¿',
    'billedTo': 'à¤¬à¤¿à¤² à¤ªà¥à¤°à¤¾à¤ªà¥à¤¤à¤•à¤°à¥à¤¤à¤¾',
    'proprietor': 'à¤®à¤¾à¤²à¤¿à¤•',
    'mobile': 'à¤®à¥‹à¤¬à¤¾à¤‡à¤²',
    'email': 'à¤ˆà¤®à¥‡à¤²',
    'slNo': 'à¤•à¥à¤°.',
    'description': 'à¤µà¤¿à¤µà¤°à¤£',
    'qty': 'à¤®à¤¾à¤¤à¥à¤°à¤¾',
    'unit': 'à¤‡à¤•à¤¾à¤ˆ',
    'rate': 'à¤¦à¤°',
    'tax': 'à¤•à¤°',
    'discount': 'à¤›à¥‚à¤Ÿ',
    'amount': 'à¤°à¤¾à¤¶à¤¿',
    'subtotal': 'à¤‰à¤ª-à¤¯à¥‹à¤—',
    'taxAmount': 'à¤•à¤° à¤°à¤¾à¤¶à¤¿',
    'grandTotal': 'à¤•à¥à¤² à¤¯à¥‹à¤—',
    'amountInWords': 'à¤¶à¤¬à¥à¤¦à¥‹à¤‚ à¤®à¥‡à¤‚ à¤°à¤¾à¤¶à¤¿',
    'notes': 'à¤Ÿà¤¿à¤ªà¥à¤ªà¤£à¥€',
    'termsConditions': 'à¤¨à¤¿à¤¯à¤® à¤”à¤° à¤¶à¤°à¥à¤¤à¥‡à¤‚',
    'authorizedSignature': 'à¤…à¤§à¤¿à¤•à¥ƒà¤¤ à¤¹à¤¸à¥à¤¤à¤¾à¤•à¥à¤·à¤°',
    'thankYou':
        'à¤†à¤ªà¤•à¥‡ à¤µà¥à¤¯à¤¾à¤ªà¤¾à¤° à¤•à¥‡ à¤²à¤¿à¤ à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦!',
    'computerGenerated':
        'à¤¯à¤¹ à¤•à¤‚à¤ªà¥à¤¯à¥‚à¤Ÿà¤° à¤œà¤¨à¤¿à¤¤ à¤¬à¤¿à¤² à¤¹à¥ˆ',
  };

  static const Map<String, String> _marathiLabels = {
    'invoice': 'à¤¬à¤¿à¤²',
    'taxInvoice': 'à¤•à¤° à¤¬à¤¿à¤²',
    'invoiceNo': 'à¤¬à¤¿à¤² à¤•à¥à¤°à¤®à¤¾à¤‚à¤•',
    'date': 'à¤¦à¤¿à¤¨à¤¾à¤‚à¤•',
    'dueDate': 'à¤¦à¥‡à¤¯ à¤¤à¤¾à¤°à¥€à¤–',
    'billedTo': 'à¤¬à¤¿à¤² à¤ªà¥à¤°à¤¾à¤ªà¥à¤¤à¤•à¤°à¥à¤¤à¤¾',
    'proprietor': 'à¤®à¤¾à¤²à¤•',
    'mobile': 'à¤®à¥‹à¤¬à¤¾à¤ˆà¤²',
    'email': 'à¤ˆà¤®à¥‡à¤²',
    'slNo': 'à¤…à¤¨à¥.',
    'description': 'à¤µà¤°à¥à¤£à¤¨',
    'qty': 'à¤ªà¥à¤°à¤®à¤¾à¤£',
    'unit': 'à¤à¤•à¤•',
    'rate': 'à¤¦à¤°',
    'tax': 'à¤•à¤°',
    'discount': 'à¤¸à¤µà¤²à¤¤',
    'amount': 'à¤°à¤•à¥à¤•à¤®',
    'subtotal': 'à¤‰à¤ª-à¤à¤•à¥‚à¤£',
    'taxAmount': 'à¤•à¤° à¤°à¤•à¥à¤•à¤®',
    'grandTotal': 'à¤à¤•à¥‚à¤£',
    'amountInWords': 'à¤¶à¤¬à¥à¤¦à¤¾à¤¤ à¤°à¤•à¥à¤•à¤®',
    'notes': 'à¤Ÿà¥€à¤ª',
    'termsConditions': 'à¤…à¤Ÿà¥€ à¤†à¤£à¤¿ à¤¶à¤°à¥à¤¤à¥€',
    'authorizedSignature': 'à¤…à¤§à¤¿à¤•à¥ƒà¤¤ à¤¸à¥à¤µà¤¾à¤•à¥à¤·à¤°à¥€',
    'thankYou':
        'à¤†à¤ªà¤²à¥à¤¯à¤¾ à¤µà¥à¤¯à¤µà¤¸à¤¾à¤¯à¤¾à¤¸à¤¾à¤ à¥€ à¤§à¤¨à¥à¤¯à¤µà¤¾à¤¦!',
    'computerGenerated':
        'à¤¹à¥‡ à¤¸à¤‚à¤—à¤£à¤• à¤¨à¤¿à¤°à¥à¤®à¤¿à¤¤ à¤¬à¤¿à¤² à¤†à¤¹à¥‡',
  };

  static const Map<String, String> _gujaratiLabels = {
    'invoice': 'àª‡àª¨à«àªµà«‹àª‡àª¸',
    'taxInvoice': 'àªŸà«‡àª•à«àª¸ àª‡àª¨à«àªµà«‹àª‡àª¸',
    'invoiceNo': 'àª‡àª¨à«àªµà«‹àª‡àª¸ àª¨àª‚àª¬àª°',
    'date': 'àª¤àª¾àª°à«€àª–',
    'dueDate': 'àª¨àª¿àª¯àª¤ àª¤àª¾àª°à«€àª–',
    'billedTo': 'àª¬à«€àª² àªªà«àª°àª¾àªªà«àª¤àª•àª°à«àª¤àª¾',
    'proprietor': 'àª®àª¾àª²àª¿àª•',
    'mobile': 'àª®à«‹àª¬àª¾àª‡àª²',
    'email': 'àªˆàª®à«‡àªˆàª²',
    'slNo': 'àª•à«àª°.',
    'description': 'àªµàª¿àª—àª¤',
    'qty': 'àªœàª¥à«àª¥à«‹',
    'unit': 'àªàª•àª®',
    'rate': 'àª­àª¾àªµ',
    'tax': 'àª•àª°',
    'discount': 'àª›à«‚àªŸ',
    'amount': 'àª°àª•àª®',
    'subtotal': 'àªªà«‡àªŸàª¾ àª•à«àª²',
    'taxAmount': 'àª•àª° àª°àª•àª®',
    'grandTotal': 'àª•à«àª² àª°àª•àª®',
    'amountInWords': 'àª¶àª¬à«àª¦à«‹àª®àª¾àª‚ àª°àª•àª®',
    'notes': 'àª¨à«‹àª‚àª§',
    'termsConditions': 'àª¨àª¿àª¯àª®à«‹ àª…àª¨à«‡ àª¶àª°àª¤à«‹',
    'authorizedSignature': 'àª…àª§àª¿àª•à«ƒàª¤ àª¹àª¸à«àª¤àª¾àª•à«àª·àª°',
    'thankYou':
        'àª¤àª®àª¾àª°àª¾ àªµà«àª¯àªµàª¸àª¾àª¯ àª®àª¾àªŸà«‡ àª†àª­àª¾àª°!',
    'computerGenerated':
        'àª† àª•àª®à«àªªà«àª¯à«àªŸàª° àªœàª¨àª¿àª¤ àª‡àª¨à«àªµà«‹àª‡àª¸ àª›à«‡',
  };

  static const Map<String, String> _tamilLabels = {
    'invoice': 'à®µà®¿à®²à¯ˆà®ªà¯à®ªà®Ÿà¯à®Ÿà®¿à®¯à®²à¯',
    'taxInvoice': 'à®µà®°à®¿ à®µà®¿à®²à¯ˆà®ªà¯à®ªà®Ÿà¯à®Ÿà®¿à®¯à®²à¯',
    'invoiceNo': 'à®µà®¿à®²à¯ˆà®ªà¯à®ªà®Ÿà¯à®Ÿà®¿à®¯à®²à¯ à®Žà®£à¯',
    'date': 'à®¤à¯‡à®¤à®¿',
    'dueDate': 'à®¨à®¿à®²à¯à®µà¯ˆ à®¤à¯‡à®¤à®¿',
    'billedTo': 'à®ªà®¿à®²à¯ à®ªà¯†à®±à¯à®¨à®°à¯',
    'proprietor': 'à®‰à®°à®¿à®®à¯ˆà®¯à®¾à®³à®°à¯',
    'mobile': 'à®®à¯Šà®ªà¯ˆà®²à¯',
    'email': 'à®®à®¿à®©à¯à®©à®žà¯à®šà®²à¯',
    'slNo': 'à®µ.à®Žà®£à¯',
    'description': 'à®µà®¿à®µà®°à®®à¯',
    'qty': 'à®…à®³à®µà¯',
    'unit': 'à®…à®²à®•à¯',
    'rate': 'à®µà®¿à®²à¯ˆ',
    'tax': 'à®µà®°à®¿',
    'discount': 'à®¤à®³à¯à®³à¯à®ªà®Ÿà®¿',
    'amount': 'à®¤à¯Šà®•à¯ˆ',
    'subtotal': 'à®¤à¯à®£à¯ˆ à®®à¯Šà®¤à¯à®¤à®®à¯',
    'taxAmount': 'à®µà®°à®¿ à®¤à¯Šà®•à¯ˆ',
    'grandTotal': 'à®®à¯Šà®¤à¯à®¤ à®¤à¯Šà®•à¯ˆ',
    'amountInWords': 'à®šà¯Šà®±à¯à®•à®³à®¿à®²à¯ à®¤à¯Šà®•à¯ˆ',
    'notes': 'à®•à¯à®±à®¿à®ªà¯à®ªà¯à®•à®³à¯',
    'termsConditions': 'à®µà®¿à®¤à®¿à®®à¯à®±à¯ˆà®•à®³à¯',
    'authorizedSignature':
        'à®…à®™à¯à®•à¯€à®•à®°à®¿à®•à¯à®•à®ªà¯à®ªà®Ÿà¯à®Ÿ à®•à¯ˆà®¯à¯Šà®ªà¯à®ªà®®à¯',
    'thankYou':
        'à®‰à®™à¯à®•à®³à¯ à®µà®£à®¿à®•à®¤à¯à®¤à®¿à®±à¯à®•à¯ à®¨à®©à¯à®±à®¿!',
    'computerGenerated':
        'à®‡à®¤à¯ à®•à®£à®¿à®©à®¿ à®‰à®°à¯à®µà®¾à®•à¯à®•à®¿à®¯ à®µà®¿à®²à¯ˆà®ªà¯à®ªà®Ÿà¯à®Ÿà®¿à®¯à®²à¯',
  };

  static const Map<String, String> _teluguLabels = {
    'invoice': 'à°‡à°¨à±à°µà°¾à°¯à°¿à°¸à±',
    'taxInvoice': 'à°Ÿà°¾à°•à±à°¸à± à°‡à°¨à±à°µà°¾à°¯à°¿à°¸à±',
    'invoiceNo': 'à°‡à°¨à±à°µà°¾à°¯à°¿à°¸à± à°¨à°‚à°¬à°°à±',
    'date': 'à°¤à±‡à°¦à±€',
    'dueDate': 'à°šà±†à°²à±à°²à°¿à°‚à°šà°µà°²à°¸à°¿à°¨ à°¤à±‡à°¦à±€',
    'billedTo': 'à°¬à°¿à°²à± à°ªà±Šà°‚à°¦à±‡à°µà°¾à°°à±',
    'proprietor': 'à°¯à°œà°®à°¾à°¨à°¿',
    'mobile': 'à°®à±Šà°¬à±ˆà°²à±',
    'email': 'à°‡à°®à±†à°¯à°¿à°²à±',
    'slNo': 'à°•à±à°°.',
    'description': 'à°µà°¿à°µà°°à°£',
    'qty': 'à°ªà°°à°¿à°®à°¾à°£à°‚',
    'unit': 'à°¯à±‚à°¨à°¿à°Ÿà±',
    'rate': 'à°°à±‡à°Ÿà±',
    'tax': 'à°ªà°¨à±à°¨à±',
    'discount': 'à°¤à°—à±à°—à°¿à°‚à°ªà±',
    'amount': 'à°®à±Šà°¤à±à°¤à°‚',
    'subtotal': 'à°‰à°ª à°®à±Šà°¤à±à°¤à°‚',
    'taxAmount': 'à°ªà°¨à±à°¨à± à°®à±Šà°¤à±à°¤à°‚',
    'grandTotal': 'à°®à±Šà°¤à±à°¤à°‚',
    'amountInWords': 'à°®à°¾à°Ÿà°²à°²à±‹ à°®à±Šà°¤à±à°¤à°‚',
    'notes': 'à°—à°®à°¨à°¿à°•à°²à±',
    'termsConditions': 'à°¨à°¿à°¬à°‚à°§à°¨à°²à±',
    'authorizedSignature': 'à°…à°§à±€à°•à±ƒà°¤ à°¸à°‚à°¤à°•à°‚',
    'thankYou':
        'à°®à±€ à°µà±à°¯à°¾à°ªà°¾à°°à°¾à°¨à°¿à°•à°¿ à°§à°¨à±à°¯à°µà°¾à°¦à°¾à°²à±!',
    'computerGenerated':
        'à°‡à°¦à°¿ à°•à°‚à°ªà±à°¯à±‚à°Ÿà°°à± à°°à±‚à°ªà±Šà°‚à°¦à°¿à°‚à°šà°¿à°¨ à°‡à°¨à±à°µà°¾à°¯à°¿à°¸à±',
  };

  static const Map<String, String> _bengaliLabels = {
    'invoice': 'à¦šà¦¾à¦²à¦¾à¦¨',
    'taxInvoice': 'à¦Ÿà§à¦¯à¦¾à¦•à§à¦¸ à¦šà¦¾à¦²à¦¾à¦¨',
    'invoiceNo': 'à¦šà¦¾à¦²à¦¾à¦¨ à¦¨à¦®à§à¦¬à¦°',
    'date': 'à¦¤à¦¾à¦°à¦¿à¦–',
    'dueDate': 'à¦¬à¦•à§‡à¦¯à¦¼à¦¾ à¦¤à¦¾à¦°à¦¿à¦–',
    'billedTo': 'à¦¬à¦¿à¦² à¦ªà§à¦°à¦¾à¦ªà¦•',
    'proprietor': 'à¦®à¦¾à¦²à¦¿à¦•',
    'mobile': 'à¦®à§‹à¦¬à¦¾à¦‡à¦²',
    'email': 'à¦‡à¦®à§‡à¦‡à¦²',
    'slNo': 'à¦•à§à¦°.',
    'description': 'à¦¬à¦¿à¦¬à¦°à¦£',
    'qty': 'à¦ªà¦°à¦¿à¦®à¦¾à¦£',
    'unit': 'à¦à¦•à¦•',
    'rate': 'à¦¦à¦°',
    'tax': 'à¦•à¦°',
    'discount': 'à¦›à¦¾à¦¡à¦¼',
    'amount': 'à¦Ÿà¦¾à¦•à¦¾',
    'subtotal': 'à¦‰à¦ªà¦®à§‹à¦Ÿ',
    'taxAmount': 'à¦•à¦° à¦ªà¦°à¦¿à¦®à¦¾à¦£',
    'grandTotal': 'à¦¸à¦°à§à¦¬à¦®à§‹à¦Ÿ',
    'amountInWords': 'à¦•à¦¥à¦¾à¦¯à¦¼ à¦ªà¦°à¦¿à¦®à¦¾à¦£',
    'notes': 'à¦®à¦¨à§à¦¤à¦¬à§à¦¯',
    'termsConditions': 'à¦¶à¦°à§à¦¤à¦¾à¦¬à¦²à§€',
    'authorizedSignature': 'à¦…à¦¨à§à¦®à§‹à¦¦à¦¿à¦¤ à¦¸à§à¦¬à¦¾à¦•à§à¦·à¦°',
    'thankYou':
        'à¦†à¦ªà¦¨à¦¾à¦° à¦¬à§à¦¯à¦¬à¦¸à¦¾à¦° à¦œà¦¨à§à¦¯ à¦§à¦¨à§à¦¯à¦¬à¦¾à¦¦!',
    'computerGenerated':
        'à¦à¦Ÿà¦¿ à¦•à¦®à§à¦ªà¦¿à¦‰à¦Ÿà¦¾à¦° à¦¤à§ˆà¦°à¦¿ à¦šà¦¾à¦²à¦¾à¦¨',
  };
}
