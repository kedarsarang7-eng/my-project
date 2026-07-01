import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/bill.dart';

class PdfInvoiceService {
  /// Generate and optionally [share] or [print] a PDF invoice.
  Future<File> generateInvoice(Bill bill, {bool share = false}) async {
    final pdf = pw.Document();

    // Load fonts/logos if needed (placeholder)
    // final font = await PdfGoogleFonts.nunitoExtraLight();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(bill),
            pw.SizedBox(height: 20),
            _buildBillDetails(bill),
            pw.SizedBox(height: 20),
            _buildItemsTable(bill),
            pw.Divider(),
            _buildTotals(bill),
            pw.SizedBox(height: 20),
            _buildTerms(bill),
            pw.Spacer(),
            _buildFooter(bill),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${bill.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());

    if (share) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'invoice_${bill.invoiceNumber}.pdf',
      );
    }

    return file;
  }

  pw.Widget _buildHeader(Bill bill) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              bill.shopName.isEmpty ? 'My Shop' : bill.shopName,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            if (bill.shopAddress.isNotEmpty) pw.Text(bill.shopAddress),
            if (bill.shopContact.isNotEmpty)
              pw.Text('Phone: ${bill.shopContact}'),
            if (bill.shopGst.isNotEmpty) pw.Text('GSTIN: ${bill.shopGst}'),
          ],
        ),
        // Placeholder for Logo
        pw.Container(
          width: 60,
          height: 60,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data:
                'UPI://PAY?pa=example@upi&am=${bill.grandTotal}&pn=${bill.shopName}',
            drawText: false,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildBillDetails(Bill bill) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Bill To:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(bill.customerName),
            if (bill.customerPhone.isNotEmpty) pw.Text(bill.customerPhone),
            if (bill.customerAddress.isNotEmpty) pw.Text(bill.customerAddress),
            if (bill.customerGst.isNotEmpty)
              pw.Text('GSTIN: ${bill.customerGst}'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Invoice #: ${bill.invoiceNumber}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Date: ${bill.date.toString().split(' ')[0]}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(Bill bill) {
    return pw.TableHelper.fromTextArray(
      headers: ['Item', 'HSN', 'Qty', 'Price', 'GST %', 'Amount'],
      data: bill.items.map((item) {
        return [
          item.itemName,
          item.hsn,
          '${item.qty} ${item.unit}',
          item.price.toStringAsFixed(2),
          '${item.gstRate}%',
          item.total.toStringAsFixed(2),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildTotals(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _buildTotalRow('Subtotal', bill.subtotal),
        _buildTotalRow('Tax (GST)', bill.totalTax),
        if (bill.discountApplied > 0)
          _buildTotalRow('Discount', -bill.discountApplied),
        pw.Divider(),
        _buildTotalRow(
          'Grand Total',
          bill.grandTotal,
          isBold: true,
          fontSize: 16,
        ),
        _buildTotalRow('Paid Amount', bill.paidAmount),
        _buildTotalRow('Balance Due', bill.pendingAmount, color: PdfColors.red),
      ],
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 12,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label:  ',
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        pw.Text(
          '₹${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: fontSize,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTerms(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Terms & Conditions:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '1. Goods once sold will not be taken back.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          '2. Interest @ 18% p.a. will be charged if not paid within due date.',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(Bill bill) {
    return pw.Center(
      child: pw.Text(
        'Thank you for your business!',
        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
      ),
    );
  }
}
