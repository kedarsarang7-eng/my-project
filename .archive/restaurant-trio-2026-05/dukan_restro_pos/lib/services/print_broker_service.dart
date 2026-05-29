import 'dart:async';
import 'package:flutter/foundation.dart';

/// Represents a print job structure (bill, KOT, receipt, etc.)
class PrintJob {
  final String id;
  final String documentType;
  final Map<String, dynamic> data;
  int retryCount;

  PrintJob({
    required this.id,
    required this.documentType,
    required this.data,
    this.retryCount = 0,
  });
}

/// Print Broker Service manages an asynchronous queue for thermal Bluetooth prints.
/// Handles 3x retries on hardware disconnects and provides a PDF alternative fallback.
class PrintBrokerService extends ChangeNotifier {
  final List<PrintJob> _printQueue = [];
  bool _isPrinting = false;

  /// External hardware print adapter (mocked for environment abstraction)
  Future<bool> _bluetoothPrintAdapter(PrintJob job) async {
    // Simulated print delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulating a 40% chance of random thermal hardware failure
    bool hardwareSuccess = (DateTime.now().millisecond % 5) > 1; 
    return hardwareSuccess;
  }

  /// Trigger PDF generation and download link as a fallback
  Future<void> _generatePdfFallback(PrintJob job) async {
    // In production, instantiate pdf package and download/save file.
    if (kDebugMode) {
      print('>>> [PRINT BROKER] Generated PDF Fallback for ${job.documentType} (${job.id})');
    }
    // E.g., final pdf = pw.Document(); pdf.addPage(...); await file.writeAsBytes(await pdf.save());
  }

  /// Pushes a job to the queue and wakes up the processor.
  void submitPrintJob(String docType, Map<String, dynamic> data) {
    final job = PrintJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      documentType: docType,
      data: data,
    );
    _printQueue.add(job);
    _processQueue();
  }

  /// Loop through the print queue sequentially.
  Future<void> _processQueue() async {
    if (_isPrinting || _printQueue.isEmpty) return;

    _isPrinting = true;
    notifyListeners();

    while (_printQueue.isNotEmpty) {
      final job = _printQueue.first;
      bool success = false;

      try {
        success = await _bluetoothPrintAdapter(job);
      } catch (e) {
        success = false;
      }

      if (success) {
        if (kDebugMode) print('>>> [PRINT BROKER] Successfully printed ${job.id}');
        _printQueue.removeAt(0); // Pop finished job
      } else {
        job.retryCount++;
        if (kDebugMode) print('>>> [PRINT BROKER] Print failed. Retry ${job.retryCount}/3');

        if (job.retryCount >= 3) {
          if (kDebugMode) print('>>> [PRINT BROKER] Job ${job.id} MAX RETRIES exceeded. Invoking PDF Fallback.');
          await _generatePdfFallback(job);
          _printQueue.removeAt(0); // Drop failed job after fallback
        } else {
          // Wait 3 seconds before next retry
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }

    _isPrinting = false;
    notifyListeners();
  }

  int get queueLength => _printQueue.length;
  bool get isProcessing => _isPrinting;
}
