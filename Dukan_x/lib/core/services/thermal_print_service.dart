import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../models/bill.dart';
import '../errors/io_guard.dart';

enum ThermalPrinterType { escpos, browser, electron }

class ThermalPrinterSettings {
  final String width; // '80mm' | '58mm'
  final bool autoCut;
  final String encoding;

  const ThermalPrinterSettings({
    this.width = '80mm',
    this.autoCut = true,
    this.encoding = 'utf-8',
  });
}

class ThermalPrintService {
  ThermalPrinterSettings _settings = const ThermalPrinterSettings();

  Future<ThermalPrinterType> detectPrinterType() async {
    // FIXED: Explicit routing fallback when native bridge absent.
    return ThermalPrinterType.browser;
  }

  Future<void> configurePrinter(ThermalPrinterSettings settings) async {
    // FIXED: Keep printer config centralized, reusable by all print entrypoints.
    _settings = settings;
  }

  Future<Uint8List> renderThermalLayout(Bill bill) async {
    return IoGuard.run<Uint8List>(
      label: 'thermal_print.render',
      userMessage: 'Could not render the receipt. Please try again.',
      op: () async {
        final is58 = _settings.width == '58mm';
        final pageFormat = PdfPageFormat(
          (is58 ? 58 : 80) * PdfPageFormat.mm,
          double.infinity,
          marginAll: is58 ? 2 * PdfPageFormat.mm : 3 * PdfPageFormat.mm,
        );

        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) {
              return pw.DefaultTextStyle(
                style: const pw.TextStyle(fontSize: 8, fontFallback: []),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        bill.shopName.isEmpty ? 'SHOP' : bill.shopName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    if (bill.shopAddress.isNotEmpty)
                      pw.Center(child: pw.Text(bill.shopAddress)),
                    if (bill.shopGst.isNotEmpty)
                      pw.Center(child: pw.Text('GSTIN: ${bill.shopGst}')),
                    pw.SizedBox(height: 4),
                    pw.Divider(),
                    pw.Text('Invoice: ${bill.invoiceNumber}'),
                    pw.Text('Date: ${bill.date}'),
                    pw.Text(
                      'Customer: ${bill.customerName.isEmpty ? "Walk-in" : bill.customerName}',
                    ),
                    pw.Divider(),
                    ...bill.items.map(
                      (item) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                '${item.productName} x${item.qty.toStringAsFixed(2)}',
                                maxLines: 2,
                              ),
                            ),
                            pw.Text('Rs ${item.total.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    ),
                    pw.Divider(),
                    _line('Subtotal', bill.subtotal),
                    if (bill.discountApplied > 0)
                      _line('Discount', -bill.discountApplied),
                    if (bill.totalTax > 0) _line('Tax', bill.totalTax),
                    _line('Total', bill.grandTotal, bold: true),
                    pw.Divider(),
                    pw.Center(child: pw.Text('Thank You')),
                    pw.Center(child: pw.Text('Visit Again')),
                  ],
                ),
              );
            },
          ),
        );
        return doc.save();
      },
    );
  }

  Future<void> printInvoice(Bill invoiceData) async {
    final bytes = await renderThermalLayout(invoiceData);
    await IoGuard.run<void>(
      label: 'thermal_print.invoice',
      userMessage: 'Could not print the invoice. Please check the printer.',
      op: () => Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: invoiceData.invoiceNumber,
      ),
    );
  }

  Future<void> printReceipt(Bill receiptData) async {
    final bytes = await renderThermalLayout(receiptData);
    await IoGuard.run<void>(
      label: 'thermal_print.receipt',
      userMessage: 'Could not print the receipt. Please check the printer.',
      op: () => Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Receipt_${receiptData.id}',
      ),
    );
  }

  Future<void> testPrint() async {
    final testBill = Bill.empty().copyWith(
      invoiceNumber: 'TEST-THERMAL',
      customerName: 'Test',
      date: DateTime.now(),
      items: [
        BillItem(
          productId: 'test',
          productName: 'Printer Test Item',
          qty: 1,
          price: 1,
        ),
      ],
      subtotal: 1,
      grandTotal: 1,
    );
    await printReceipt(testBill);
  }

  List<int> getEscPosCutCommand() {
    // FIXED: Standard ESC/POS full-cut command exposed for native drivers.
    if (!_settings.autoCut) return const [];
    return const [0x1D, 0x56, 0x00];
  }

  pw.Widget _line(String label, double amount, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          amount.toStringAsFixed(2),
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
