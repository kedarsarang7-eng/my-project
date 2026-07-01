/// Invoice PDF Generation with IMEI Support
/// Extension to include IMEI details in mobile shop invoices
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:dukanx/models/bill.dart';

/// Mixin for adding IMEI details to invoice PDFs
class InvoiceIMEIExtension {
  /// Generate IMEI section for invoice
  static pw.Widget buildIMEISection({
    required List<BillItem> items,
    required pw.TextStyle headerStyle,
    required pw.TextStyle normalStyle,
    required pw.TextStyle smallStyle,
  }) {
    final imeiItems = items.where((item) => 
      item.serialNo != null && item.serialNo!.isNotEmpty
    ).toList();

    if (imeiItems.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text(
          'Device Details (IMEI/Serial Numbers)',
          style: headerStyle.copyWith(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Product', style: smallStyle.copyWith(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Qty', style: smallStyle.copyWith(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('IMEI/Serial Number', style: smallStyle.copyWith(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            // Data rows
            ...imeiItems.map((item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(item.productName, style: smallStyle),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('${item.qty.toInt()}', style: smallStyle),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    item.serialNo ?? 'N/A',
                    style: smallStyle.copyWith(font: pw.Font.courier()),
                  ),
                ),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Note: Please verify IMEI/Serial numbers at the time of delivery. '
          'Goods once sold with verified IMEI cannot be returned.',
          style: smallStyle.copyWith(
            fontSize: 9,
            color: PdfColors.grey600,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Build warranty information section
  static pw.Widget buildWarrantySection({
    required List<BillItem> items,
    required pw.TextStyle headerStyle,
    required pw.TextStyle normalStyle,
    required pw.TextStyle smallStyle,
  }) {
    final warrantyItems = items.where((item) => 
      item.warrantyMonths != null && item.warrantyMonths! > 0
    ).toList();

    if (warrantyItems.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Text(
          'Warranty Information',
          style: headerStyle.copyWith(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Product', style: smallStyle.copyWith(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Warranty Period', style: smallStyle.copyWith(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Warranty Terms', style: smallStyle.copyWith(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...warrantyItems.map((item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(item.productName, style: smallStyle),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    '${item.warrantyMonths} Months',
                    style: smallStyle,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Manufacturer warranty. Physical & liquid damage not covered.',
                    style: smallStyle.copyWith(fontSize: 8),
                  ),
                ),
              ],
            )),
          ],
        ),
      ],
    );
  }

  /// Build exchange/buyback section for invoice
  static pw.Widget buildExchangeSection({
    String? oldDeviceName,
    String? oldDeviceIMEI,
    double? exchangeValue,
    required pw.TextStyle headerStyle,
    required pw.TextStyle normalStyle,
    required pw.TextStyle smallStyle,
  }) {
    if (oldDeviceName == null || exchangeValue == null || exchangeValue <= 0) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Exchange Details',
                style: headerStyle.copyWith(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Old Device: $oldDeviceName', style: smallStyle),
                        if (oldDeviceIMEI != null)
                          pw.Text('Old Device IMEI: $oldDeviceIMEI', style: smallStyle.copyWith(font: pw.Font.courier())),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Exchange Value: ₹${exchangeValue.toStringAsFixed(2)}',
                        style: normalStyle.copyWith(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build footer with mobile shop specific terms
  static pw.Widget buildMobileShopFooter(pw.TextStyle smallStyle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Terms & Conditions:',
          style: smallStyle.copyWith(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '1. Please verify IMEI/Serial numbers at the time of delivery.',
          style: smallStyle.copyWith(fontSize: 9),
        ),
        pw.Text(
          '2. Goods once sold cannot be returned. Exchange allowed within 7 days with original packaging.',
          style: smallStyle.copyWith(fontSize: 9),
        ),
        pw.Text(
          '3. Warranty as per manufacturer terms. Physical/liquid damage not covered.',
          style: smallStyle.copyWith(fontSize: 9),
        ),
        pw.Text(
          '4. For warranty claims, please bring this invoice and the device to our service center.',
          style: smallStyle.copyWith(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'E. & O.E.',
          style: smallStyle.copyWith(fontSize: 9, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }
}

/// Extension on Bill to get IMEI information
extension BillIMEIExtension on Bill {
  /// Check if bill has any IMEI-tracked items
  bool get hasIMEIItems {
    return items.any((item) => item.serialNo != null && item.serialNo!.isNotEmpty);
  }

  /// Get count of items with IMEI
  int get imeiItemCount {
    return items.where((item) => item.serialNo != null && item.serialNo!.isNotEmpty).length;
  }

  /// Get all IMEI numbers from bill
  List<String> get allIMEINumbers {
    return items
        .where((item) => item.serialNo != null && item.serialNo!.isNotEmpty)
        .map((item) => item.serialNo!)
        .toList();
  }
}
