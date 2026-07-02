import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/universal_invoice_data.dart';

/// Shared PDF section builders reused by BOTH the config-driven universal PDF
/// builder and the dedicated-template PDF builders. Mirrors the on-screen
/// [InvoiceSharedSections] in the PDF (pw) domain so the print output stays
/// consistent with the preview and free of business-type conditionals.
///
/// Uses the built-in Helvetica font (no asset loading) so PDFs build in pure
/// Dart tests. Currency is rendered as 'Rs.' because the standard PDF font has
/// no rupee glyph.
class InvoicePdfSections {
  static pw.Widget businessInfo(UniversalInvoiceData d) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        d.shopName,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      if (d.tagline != null && d.tagline!.isNotEmpty) pw.Text(d.tagline!),
      pw.Text(d.address),
      pw.Text('Mobile: ${d.mobile}'),
      if (d.gstin != null && d.gstin!.isNotEmpty) pw.Text('GSTIN: ${d.gstin}'),
      if (d.drugLicenseNumber != null && d.drugLicenseNumber!.isNotEmpty)
        pw.Text('DL No: ${d.drugLicenseNumber}'),
      pw.Divider(),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Invoice #${d.invoiceNumber}'),
          pw.Text(date(d.date)),
        ],
      ),
    ],
  );

  static pw.Widget customerInfo(UniversalInvoiceData d) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Bill To:', style: _bold),
      pw.Text(d.customerName.isEmpty ? 'Walk-in Customer' : d.customerName),
      if (d.customerMobile.isNotEmpty) pw.Text(d.customerMobile),
      if (d.customerAddress != null && d.customerAddress!.isNotEmpty)
        pw.Text(d.customerAddress!),
      if (d.customerGstin != null && d.customerGstin!.isNotEmpty)
        pw.Text('GSTIN: ${d.customerGstin}'),
    ],
  );

  static pw.Widget shipping(UniversalInvoiceData d) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Ship To:', style: _bold),
      pw.Text(d.shippingAddress ?? d.customerAddress ?? '-'),
      if (d.transportDetails != null && d.transportDetails!.isNotEmpty)
        pw.Text('Transport: ${d.transportDetails}'),
    ],
  );

  static pw.Widget tax(UniversalInvoiceData d) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        if (!d.isInterState) ...[
          pw.Text('CGST: ${money(d.totalCgst)}'),
          pw.Text('SGST: ${money(d.totalSgst)}'),
        ],
        if (d.isInterState) pw.Text('IGST: ${money(d.totalIgst)}'),
        pw.Text('Tax Total: ${money(d.totalTax)}'),
      ],
    ),
  );

  static pw.Widget discount(UniversalInvoiceData d) {
    if (d.totalDiscount <= 0) return pw.SizedBox();
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Discount: -${money(d.totalDiscount)}'),
    );
  }

  static pw.Widget payment(UniversalInvoiceData d) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('TOTAL: ${money(d.grandTotal)}', style: _bold),
      ),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Mode: ${d.paymentMode}'),
          pw.Text('Paid: ${money(d.paidAmount)}'),
          pw.Text('Due: ${money(d.dueAmount)}'),
        ],
      ),
    ],
  );

  static pw.Widget bankDetails(UniversalInvoiceData d) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Bank Details:', style: _bold),
      pw.Text('Bank: ${d.bankName ?? '-'}'),
      pw.Text('A/C: ${d.bankAccountNumber ?? '-'}'),
      pw.Text('IFSC: ${d.bankIfsc ?? '-'}'),
    ],
  );

  static pw.Widget warranty(UniversalInvoiceData d) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Warranty:', style: _bold),
      pw.Text(
        d.warrantyTerms ??
            'Warranty valid only with original invoice. Terms apply.',
      ),
    ],
  );

  static pw.Widget serialImei(UniversalInvoiceData d) => pw.Text(
    'IMEI / Serial numbers above are required for warranty claims.',
    style: const pw.TextStyle(fontSize: 8),
  );

  static pw.Widget notes(UniversalInvoiceData d) {
    if (d.notes == null || d.notes!.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Notes:', style: _bold),
        pw.Text(d.notes!),
      ],
    );
  }

  static pw.Widget terms(UniversalInvoiceData d) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Terms & Conditions:', style: _bold),
      pw.Text(d.terms ?? 'Thank you for your business!'),
    ],
  );

  static pw.Widget qr(UniversalInvoiceData d) => pw.Row(
    children: [
      pw.Container(
        width: 48,
        height: 48,
        decoration: pw.BoxDecoration(border: pw.Border.all()),
        alignment: pw.Alignment.center,
        child: pw.Text('QR'),
      ),
      pw.SizedBox(width: 8),
      pw.Expanded(
        child: pw.Text(
          d.upiId != null && d.upiId!.isNotEmpty
              ? 'Scan to Pay: ${d.upiId}'
              : 'Scan to Pay',
        ),
      ),
    ],
  );

  static pw.Widget signature(UniversalInvoiceData d) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Column(
      children: [
        pw.SizedBox(width: 120, child: pw.Divider()),
        pw.Text('Authorized Signatory'),
      ],
    ),
  );

  /// Full tabular product table (A4). Columns come from [headers] and each row
  /// from [cells]; both are supplied by the caller so this stays generic.
  static pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(h, style: _bold),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (r) => pw.TableRow(
            children: r
                .map(
                  (cell) => pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                      cell,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Compact per-item block layout for thermal receipts. Each item renders as
  /// 'label: value' lines from the same column definitions.
  static pw.Widget compactTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (final r in rows) ...[
          pw.Divider(height: 2),
          for (var i = 0; i < headers.length && i < r.length; i++)
            if (headers[i] != '#')
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(headers[i], style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(r[i], style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
        ],
      ],
    );
  }

  static final pw.TextStyle _bold = pw.TextStyle(
    fontWeight: pw.FontWeight.bold,
  );

  static String money(double v) => '\u20B9${v.toStringAsFixed(2)}';

  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
