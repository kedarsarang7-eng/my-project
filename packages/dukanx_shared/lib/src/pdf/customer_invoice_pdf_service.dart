import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/customer_invoice.dart';
import '../utils/currency_formatter.dart';

class CustomerInvoicePdfService {
  CustomerInvoicePdfService._();

  static Future<Uint8List> generate(CustomerInvoice invoice) async {
    final doc = pw.Document(
      title: 'Invoice ${invoice.invoiceNumber}',
      author: invoice.vendorName,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(invoice),
            pw.SizedBox(height: 24),
            _addresses(invoice),
            pw.SizedBox(height: 20),
            _itemsTable(invoice),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _totals(invoice),
            ),
            pw.SizedBox(height: 24),
            _footer(invoice),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(CustomerInvoice invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(
            invoice.vendorBusinessName ?? invoice.vendorName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (invoice.vendorPhone != null)
            pw.Text(invoice.vendorPhone!,
                style: const pw.TextStyle(fontSize: 10)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('INVOICE',
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800)),
          pw.Text('# ${invoice.invoiceNumber}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            DateFormat('dd MMM yyyy').format(invoice.invoiceDate),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ]),
      ],
    );
  }

  static pw.Widget _addresses(CustomerInvoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('BILL TO',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(invoice.vendorName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ]),
          if (invoice.dueDate != null)
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('DUE DATE',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text(
                DateFormat('dd MMM yyyy').format(invoice.dueDate!),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ]),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable(CustomerInvoice invoice) {
    const headers = ['Item', 'Qty', 'Unit Price', 'Tax', 'Total'];
    final rows = invoice.items.map((item) => [
          item.name,
          '${item.quantity} ${item.unit}',
          CurrencyFormatter.format(item.unitPrice),
          '${item.taxPercent.toStringAsFixed(0)}%',
          CurrencyFormatter.format(item.total),
        ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle:
          pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.blue800),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  static pw.Widget _totals(CustomerInvoice invoice) {
    return pw.Container(
      width: 200,
      child: pw.Column(children: [
        _totalRow('Subtotal', CurrencyFormatter.format(invoice.subtotal)),
        if (invoice.discountAmount > 0)
          _totalRow('Discount',
              '- ${CurrencyFormatter.format(invoice.discountAmount)}'),
        if (invoice.taxAmount > 0)
          _totalRow('Tax', CurrencyFormatter.format(invoice.taxAmount)),
        pw.Divider(),
        _totalRow(
          'Total',
          CurrencyFormatter.format(invoice.totalAmount),
          bold: true,
        ),
        if (invoice.paidAmount > 0) ...[
          _totalRow('Paid', CurrencyFormatter.format(invoice.paidAmount)),
          _totalRow(
            'Balance Due',
            CurrencyFormatter.format(invoice.balanceDue),
            bold: true,
            color: PdfColors.red700,
          ),
        ],
      ]),
    );
  }

  static pw.Widget _totalRow(String label, String value,
      {bool bold = false, PdfColor? color}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)
        : pw.TextStyle(color: color);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static pw.Widget _footer(CustomerInvoice invoice) {
    if (invoice.notes == null) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Notes',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}
