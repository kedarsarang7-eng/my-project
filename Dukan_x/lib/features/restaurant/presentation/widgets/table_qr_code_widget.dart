// ============================================================================
// TABLE QR CODE WIDGET
// ============================================================================
// Displays and manages QR codes for restaurant tables

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../data/models/restaurant_table_model.dart';
import '../../domain/services/qr_code_service.dart';

class TableQrCodeWidget extends StatelessWidget {
  final RestaurantTable table;
  final String restaurantName;
  final String? restaurantLogo;
  final double size;
  final bool showActions;

  const TableQrCodeWidget({
    super.key,
    required this.table,
    required this.restaurantName,
    this.restaurantLogo,
    this.size = 200,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = QrCodeService().generateTableQrData(
      table.vendorId,
      table.id,
      table.tableNumber,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR Code with branding
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Restaurant name header
              Text(
                restaurantName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // QR Code
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
                embeddedImage: restaurantLogo != null
                    ? NetworkImage(restaurantLogo!)
                    : null,
                embeddedImageStyle: const QrEmbeddedImageStyle(
                  size: Size(40, 40),
                ),
              ),

              const SizedBox(height: 8),

              // Table number
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Table ${table.tableNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Scan instruction
              const Text(
                'Scan to view menu & order',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Action buttons
        if (showActions) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Print button
              ElevatedButton.icon(
                onPressed: () => _printQrCode(context, qrData),
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
              const SizedBox(width: 12),
              // Share button
              OutlinedButton.icon(
                onPressed: () => _shareQrCode(context, qrData),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _printQrCode(BuildContext context, String qrData) async {
    final pdf = pw.Document();

    // Generate QR image
    final qrImage = await _generateQrImage(qrData);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          100 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  restaurantName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: 60 * PdfPageFormat.mm,
                  height: 60 * PdfPageFormat.mm,
                  child: pw.Image(pw.MemoryImage(qrImage)),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    'Table ${table.tableNumber}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Scan to view menu & order',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Table_${table.tableNumber}_QR',
    );
  }

  Future<void> _shareQrCode(BuildContext context, String qrData) async {
    final pdf = pw.Document();
    final qrImage = await _generateQrImage(qrData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  restaurantName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  width: 80 * PdfPageFormat.mm,
                  height: 80 * PdfPageFormat.mm,
                  child: pw.Image(pw.MemoryImage(qrImage)),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    'Table ${table.tableNumber}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  'Scan to view menu & place your order',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Table_${table.tableNumber}_QR.pdf',
    );
  }

  Future<Uint8List> _generateQrImage(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
    );

    final image = await qrPainter.toImage(300);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

/// Dialog to show and manage QR code
class TableQrCodeDialog extends StatelessWidget {
  final RestaurantTable table;
  final String restaurantName;

  const TableQrCodeDialog({
    super.key,
    required this.table,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Table QR Code',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TableQrCodeWidget(
              table: table,
              restaurantName: restaurantName,
              showActions: true,
            ),
          ],
        ),
      ),
    );
  }

  static void show(
    BuildContext context, {
    required RestaurantTable table,
    required String restaurantName,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          TableQrCodeDialog(table: table, restaurantName: restaurantName),
    );
  }
}

/// Print multiple QR codes at once
class BulkQrCodePrinter {
  static Future<void> printAllTableQrCodes({
    required List<RestaurantTable> tables,
    required String restaurantName,
  }) async {
    final pdf = pw.Document();
    final qrService = QrCodeService();

    for (final table in tables) {
      final qrData = qrService.generateTableQrData(
        table.vendorId,
        table.id,
        table.tableNumber,
      );

      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      final image = await qrPainter.toImage(300);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final qrImage = byteData!.buffer.asUint8List();

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(
            80 * PdfPageFormat.mm,
            100 * PdfPageFormat.mm,
            marginAll: 5 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    restaurantName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 60 * PdfPageFormat.mm,
                    height: 60 * PdfPageFormat.mm,
                    child: pw.Image(pw.MemoryImage(qrImage)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      'Table ${table.tableNumber}',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Scan to view menu & order',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'All_Tables_QR',
    );
  }
}
