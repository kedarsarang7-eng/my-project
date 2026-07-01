// ============================================================================
// ACADEMIC COACHING — THERMAL PRINTER SERVICE
// ============================================================================
// For printing ID cards and receipts on thermal printers (ESC/POS compatible)

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Dummy classes to support compilation without external dependencies that have version conflicts
class PrinterDevice {
  final String name;
  final String address;
  const PrinterDevice({required this.name, required this.address});
}

class PrinterType {
  static const int usb = 1;
}

class BluetoothPrinter {
  static const int generic = 1;
}

class PrinterManager {
  static final PrinterManager _instance = PrinterManager._();
  PrinterManager._();
  static PrinterManager get instance => _instance;

  Stream<PrinterDevice>? discovery({required int type, required bool isBle}) =>
      null;
  Future<bool> connect({
    required int type,
    required int model,
    required String address,
  }) async => false;
  Future<void> disconnect({required int type}) async {}
  bool get isConnected => false;
  Future<bool> send({required int type, required Uint8List bytes}) async =>
      false;
}

class CapabilityProfile {
  static Future<CapabilityProfile> load() async => CapabilityProfile();
}

class Generator {
  final dynamic paperSize;
  final dynamic profile;
  Generator(this.paperSize, this.profile);

  List<int> setGlobalCodeTable(String code) => [];
  List<int> hr() => [];
  List<int> text(String text, {PosStyles styles = const PosStyles()}) => [];
  List<int> emptyLines(int lines) => [];
  List<int> cut() => [];
  List<int> row(List<PosColumn> columns) => [];
}

class PaperSize {
  static const int mm80 = 1;
}

class PosAlign {
  static const int center = 1;
  static const int right = 2;
}

class PosTextSize {
  static const int size2 = 2;
}

class PosFontType {
  static const int fontB = 2;
}

class PosStyles {
  final int? align;
  final bool bold;
  final int? height;
  final int? width;
  final int? fontType;

  const PosStyles({
    this.align,
    this.bold = false,
    this.height,
    this.width,
    this.fontType,
  });
}

class PosColumn {
  final String text;
  final int width;
  final PosStyles styles;

  PosColumn({
    required this.text,
    required this.width,
    this.styles = const PosStyles(),
  });
}

class AcThermalPrintService {
  static final AcThermalPrintService _instance =
      AcThermalPrintService._internal();
  factory AcThermalPrintService() => _instance;
  AcThermalPrintService._internal();

  PrinterManager? _printerManager;
  List<PrinterDevice> _devices = [];
  StreamSubscription<PrinterDevice>? _scanSubscription;

  // Printer type
  final int _printerType = PrinterType.usb;

  /// Initialize printer manager
  void initialize() {
    _printerManager = PrinterManager.instance;
  }

  /// Scan for available printers
  Future<List<PrinterDevice>> scanPrinters() async {
    _devices = [];

    try {
      _scanSubscription?.cancel();

      final stream = _printerManager?.discovery(
        type: _printerType,
        isBle: false,
      );
      if (stream != null) {
        await for (final device in stream) {
          _devices.add(device);
        }
      }
    } catch (e) {
      print('Error scanning printers: $e');
    }

    return _devices;
  }

  /// Connect to a printer
  Future<bool> connect(PrinterDevice device) async {
    try {
      return await _printerManager?.connect(
            type: _printerType,
            model: BluetoothPrinter.generic,
            address: device.address,
          ) ??
          false;
    } catch (e) {
      print('Error connecting to printer: $e');
      return false;
    }
  }

  /// Disconnect from printer
  Future<void> disconnect() async {
    await _printerManager?.disconnect(type: _printerType);
  }

  /// Check if printer is connected
  Future<bool> isConnected() async {
    return _printerManager?.isConnected ?? false;
  }

  /// Print ID card on thermal printer
  Future<bool> printIdCard({
    required String studentName,
    required String studentId,
    String? batchName,
    String? courseName,
    required String instituteName,
    String? validUntil,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.hr();

      // Institute name (center, large)
      bytes += generator.text(
        instituteName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.hr();

      // ID Card Title
      bytes += generator.text(
        'STUDENT ID CARD',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.emptyLines(1);

      // Student Name
      bytes += generator.text('Name:', styles: const PosStyles(bold: true));
      bytes += generator.text(
        studentName,
        styles: const PosStyles(height: PosTextSize.size2),
      );
      bytes += generator.emptyLines(1);

      // Student ID
      bytes += generator.text(
        'ID: $studentId',
        styles: const PosStyles(bold: true),
      );

      // Batch
      if (batchName != null) {
        bytes += generator.text('Batch: $batchName');
      }

      // Course
      if (courseName != null) {
        bytes += generator.text('Course: $courseName');
      }

      bytes += generator.hr();

      // Valid Until
      if (validUntil != null) {
        bytes += generator.text(
          'Valid Until: $validUntil',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      // Footer
      bytes += generator.emptyLines(2);
      bytes += generator.text(
        'This card is property of $instituteName',
        styles: const PosStyles(
          align: PosAlign.center,
          fontType: PosFontType.fontB,
        ),
      );
      bytes += generator.text(
        'If found, please return.',
        styles: const PosStyles(
          align: PosAlign.center,
          fontType: PosFontType.fontB,
        ),
      );

      bytes += generator.emptyLines(3);
      bytes += generator.cut();

      // Send to printer
      return await _printerManager?.send(
            type: _printerType,
            bytes: Uint8List.fromList(bytes),
          ) ??
          false;
    } catch (e) {
      print('Error printing ID card: $e');
      return false;
    }
  }

  /// Print fee receipt
  Future<bool> printFeeReceipt({
    required String studentName,
    required String studentId,
    required String invoiceNumber,
    required double amount,
    required String paymentMode,
    String? transactionId,
    required String date,
    required String instituteName,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.text(
        instituteName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'FEE RECEIPT',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.hr();

      // Receipt details
      bytes += generator.row([
        PosColumn(text: 'Receipt No:', width: 6),
        PosColumn(
          text: invoiceNumber,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Date:', width: 6),
        PosColumn(
          text: date,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr();

      // Student details
      bytes += generator.text('Student: $studentName');
      bytes += generator.text('ID: $studentId');
      bytes += generator.emptyLines(1);

      // Payment details
      bytes += generator.row([
        PosColumn(text: 'Amount Paid:', width: 6),
        PosColumn(
          text: 'Rs. ${amount.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += generator.text('Payment Mode: $paymentMode');
      if (transactionId != null) {
        bytes += generator.text('Transaction ID: $transactionId');
      }

      bytes += generator.hr();
      bytes += generator.text(
        'Thank you for your payment!',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.emptyLines(3);
      bytes += generator.cut();

      return await _printerManager?.send(
            type: _printerType,
            bytes: Uint8List.fromList(bytes),
          ) ??
          false;
    } catch (e) {
      print('Error printing receipt: $e');
      return false;
    }
  }

  /// Print attendance summary
  Future<bool> printAttendanceSummary({
    required String batchName,
    required String date,
    required int present,
    required int absent,
    required int total,
    required String instituteName,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.text(
        instituteName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'ATTENDANCE SUMMARY',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.hr();

      bytes += generator.text('Batch: $batchName');
      bytes += generator.text('Date: $date');
      bytes += generator.emptyLines(1);

      bytes += generator.row([
        PosColumn(text: 'Present:', width: 6),
        PosColumn(
          text: '$present',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Absent:', width: 6),
        PosColumn(
          text: '$absent',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(
          text: 'Total:',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '$total',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      if (total > 0) {
        final percentage = ((present / total) * 100).toStringAsFixed(1);
        bytes += generator.emptyLines(1);
        bytes += generator.text(
          'Attendance: $percentage%',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }

      bytes += generator.emptyLines(3);
      bytes += generator.cut();

      return await _printerManager?.send(
            type: _printerType,
            bytes: Uint8List.fromList(bytes),
          ) ??
          false;
    } catch (e) {
      print('Error printing attendance: $e');
      return false;
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    disconnect();
  }
}

/// Printer selection dialog
class PrinterSelectionDialog extends StatefulWidget {
  const PrinterSelectionDialog({super.key});

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  final AcThermalPrintService _printService = AcThermalPrintService();
  List<PrinterDevice> _devices = [];
  bool _isScanning = true;
  PrinterDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _scanPrinters();
  }

  Future<void> _scanPrinters() async {
    setState(() => _isScanning = true);
    _printService.initialize();
    final devices = await _printService.scanPrinters();
    setState(() {
      _devices = devices;
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Printer'),
      content: SizedBox(
        width: 300,
        height: 200,
        child: _isScanning
            ? const Center(child: CircularProgressIndicator())
            : _devices.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.print_disabled,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text('No printers found'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _scanPrinters,
                      child: const Text('Scan Again'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return RadioListTile<PrinterDevice>(
                    title: Text(device.name),
                    subtitle: Text(device.address),
                    value: device,
                    groupValue: _selectedDevice,
                    onChanged: (value) {
                      setState(() => _selectedDevice = value);
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedDevice != null
              ? () => Navigator.pop(context, _selectedDevice)
              : null,
          child: const Text('Select'),
        ),
      ],
    );
  }
}
