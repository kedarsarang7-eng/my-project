// ============================================================================
// RESTAURANT PDF BILL SERVICE
// ============================================================================
// Generates PDF bills with restaurant branding

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../../data/models/restaurant_bill_model.dart';
import '../../data/models/food_order_model.dart';

class RestaurantPdfBillService {
  /// Generate a PDF bill
  Future<Uint8List> generateBill({
    required RestaurantBill bill,
    required FoodOrder order,
    required String restaurantName,
    required String restaurantAddress,
    String? restaurantPhone,
    String? restaurantGstin,
    String? restaurantFssai,
    String? logoPath,
  }) async {
    try {
      final pdf = pw.Document();

      // Load font
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(10),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header - Restaurant Name
                pw.Text(
                  restaurantName.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                ),
                pw.SizedBox(height: 4),

                // Address
                pw.Text(
                  restaurantAddress,
                  style: pw.TextStyle(font: font, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),

                // Phone
                if (restaurantPhone != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Tel: $restaurantPhone',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],

                // GSTIN
                if (restaurantGstin != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'GSTIN: $restaurantGstin',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],

                // FSSAI
                if (restaurantFssai != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'FSSAI: $restaurantFssai',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],

                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.5),

                // Bill Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Bill No: ${bill.billNumber}',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                    ),
                    pw.Text(
                      order.tableNumber != null
                          ? 'Table: ${order.tableNumber}'
                          : 'Takeaway',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      _formatDateTime(bill.createdAt),
                      style: pw.TextStyle(font: font, fontSize: 8),
                    ),
                    if (order.customerName != null)
                      pw.Text(
                        order.customerName!,
                        style: pw.TextStyle(font: font, fontSize: 8),
                      ),
                  ],
                ),

                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.5),

                // Column Headers
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(font: fontBold, fontSize: 8),
                      ),
                    ),
                    pw.SizedBox(
                      width: 25,
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(font: fontBold, fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(
                      width: 35,
                      child: pw.Text(
                        'Rate',
                        style: pw.TextStyle(font: fontBold, fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text(
                        'Amt',
                        style: pw.TextStyle(font: fontBold, fontSize: 8),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),

                // Items
                ...order.items.map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(
                            item.itemName,
                            style: pw.TextStyle(font: font, fontSize: 8),
                          ),
                        ),
                        pw.SizedBox(
                          width: 25,
                          child: pw.Text(
                            item.quantity.toString(),
                            style: pw.TextStyle(font: font, fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.SizedBox(
                          width: 35,
                          child: pw.Text(
                            item.unitPrice.toStringAsFixed(0),
                            style: pw.TextStyle(font: font, fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.SizedBox(
                          width: 40,
                          child: pw.Text(
                            item.totalPrice.toStringAsFixed(0),
                            style: pw.TextStyle(font: font, fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),

                // Subtotal
                _buildTotalRow('Subtotal', bill.subtotal, font),

                // Taxes
                if (bill.cgst > 0) _buildTotalRow('CGST', bill.cgst, font),
                if (bill.sgst > 0) _buildTotalRow('SGST', bill.sgst, font),

                // Discounts
                if (bill.discountAmount > 0)
                  _buildTotalRow('Discount', -bill.discountAmount, font),

                // Service charge
                if (bill.serviceCharge > 0)
                  _buildTotalRow('Service Charge', bill.serviceCharge, font),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),

                // Grand Total
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRAND TOTAL',
                      style: pw.TextStyle(font: fontBold, fontSize: 12),
                    ),
                    pw.Text(
                      '₹${bill.grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 12),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),

                // Payment Status
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    bill.paymentStatus == BillPaymentStatus.paid
                        ? 'PAID'
                        : 'UNPAID',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
                ),

                // Payment Method
                if (bill.paymentMode != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Paid via: ${bill.paymentMode}',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ],

                pw.SizedBox(height: 12),

                // Footer
                pw.Text(
                  'Thank you for dining with us!',
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Please visit again',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),

                pw.SizedBox(height: 20),
              ],
            );
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      throw Exception('Failed to generate bill: $e');
    }
  }

  pw.Widget _buildTotalRow(String label, double amount, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8)),
          pw.Text(
            '₹${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(font: font, fontSize: 8),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Print the bill directly
  Future<void> printBill({
    required RestaurantBill bill,
    required FoodOrder order,
    required String restaurantName,
    required String restaurantAddress,
    String? restaurantPhone,
    String? restaurantGstin,
    String? restaurantFssai,
  }) async {
    try {
      final pdfData = await generateBill(
        bill: bill,
        order: order,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
        restaurantGstin: restaurantGstin,
        restaurantFssai: restaurantFssai,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfData,
        name: 'Bill_${bill.billNumber}',
      );
    } catch (e) {
      throw Exception('Failed to print bill: $e');
    }
  }

  /// Share the bill as PDF
  Future<void> shareBill({
    required RestaurantBill bill,
    required FoodOrder order,
    required String restaurantName,
    required String restaurantAddress,
    String? restaurantPhone,
    String? restaurantGstin,
    String? restaurantFssai,
  }) async {
    try {
      final pdfData = await generateBill(
        bill: bill,
        order: order,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
        restaurantGstin: restaurantGstin,
        restaurantFssai: restaurantFssai,
      );

      await Printing.sharePdf(
        bytes: pdfData,
        filename: 'Bill_${bill.billNumber}.pdf',
      );
    } catch (e) {
      throw Exception('Failed to share bill: $e');
    }
  }
}
