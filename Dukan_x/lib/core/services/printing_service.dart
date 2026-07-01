// ============================================================================
// PRINTING SERVICE - With Offline Queue & Retry Logic (P1 FIX)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import '../../../core/services/logger_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:hive/hive.dart';

/// Print job status
enum PrintJobStatus {
  queued,
  printing,
  completed,
  failed,
  offline,
  cancelled,
}

/// Print job model
class PrintJob {
  final String id;
  final String documentData; // Base64 encoded PDF
  final String printerName;
  final String documentType; // 'receipt', 'invoice', 'report'
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? errorMessage;
  final int retryCount;
  final Map<String, dynamic>? metadata;

  PrintJob({
    required this.id,
    required this.documentData,
    required this.printerName,
    required this.documentType,
    this.status = PrintJobStatus.queued,
    required this.createdAt,
    this.processedAt,
    this.errorMessage,
    this.retryCount = 0,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentData': documentData,
    'printerName': printerName,
    'documentType': documentType,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'errorMessage': errorMessage,
    'retryCount': retryCount,
    'metadata': metadata,
  };

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    return PrintJob(
      id: json['id'],
      documentData: json['documentData'],
      printerName: json['printerName'],
      documentType: json['documentType'],
      status: PrintJobStatus.values.byName(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      processedAt: json['processedAt'] != null ? DateTime.parse(json['processedAt']) : null,
      errorMessage: json['errorMessage'],
      retryCount: json['retryCount'] ?? 0,
      metadata: json['metadata'],
    );
  }

  PrintJob copyWith({
    PrintJobStatus? status,
    DateTime? processedAt,
    String? errorMessage,
    int? retryCount,
  }) {
    return PrintJob(
      id: id,
      documentData: documentData,
      printerName: printerName,
      documentType: documentType,
      status: status ?? this.status,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      metadata: metadata,
    );
  }
}

/// Printer status
class PrinterStatus {
  final String name;
  final bool isOnline;
  final bool isAvailable;
  final String? model;
  final String? error;

  PrinterStatus({
    required this.name,
    required this.isOnline,
    required this.isAvailable,
    this.model,
    this.error,
  });
}

/// P1 FIX: Printing service with offline queue
class PrintingService {
  static const String _boxName = 'print_jobs';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 30);

  Box<dynamic>? _box;
  final _statusController = StreamController<PrinterStatus>.broadcast();
  final _jobController = StreamController<PrintJob>.broadcast();
  Timer? _queueTimer;
  bool _isProcessing = false;

  /// Stream of printer status changes
  Stream<PrinterStatus> get statusStream => _statusController.stream;

  /// Stream of print job updates
  Stream<PrintJob> get jobStream => _jobController.stream;

  /// Initialize the service
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _startQueueProcessor();
  }

  /// P1 FIX: Print with offline handling
  Future<PrintJob> printDocument({
    required PdfDocument document,
    required String documentType,
    String? printerName,
    Map<String, dynamic>? metadata,
  }) async {
    await init();

    // Convert document to base64
    final bytes = await document.save();
    final base64Data = base64Encode(bytes);

    // Check printer status first
    final status = await _checkPrinterStatus(printerName);

    // Create print job
    final job = PrintJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      documentData: base64Data,
      printerName: printerName ?? 'default',
      documentType: documentType,
      status: status.isOnline ? PrintJobStatus.queued : PrintJobStatus.offline,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    // Save to queue
    await _saveJob(job);

    if (!status.isOnline) {
      // P1 FIX: Queue for later when printer is back online
      LoggerService.d('Printing', '[PrintingService] Printer offline. Job ${job.id} queued.');
      _notifyUser('Printer offline. Receipt will print when available.');
      return job;
    }

    // Try to print immediately
    await _processJob(job);
    return job;
  }

  /// P1 FIX: Check printer status
  Future<PrinterStatus> _checkPrinterStatus(String? printerName) async {
    try {
      final printers = await Printing.listPrinters();
      
      if (printers.isEmpty) {
        return PrinterStatus(
          name: printerName ?? 'default',
          isOnline: false,
          isAvailable: false,
          error: 'No printers found',
        );
      }

      final targetPrinter = printerName != null
          ? printers.firstWhere(
              (p) => p.name == printerName,
              orElse: () => printers.first,
            )
          : printers.first;

      // Try to get printer info
      final isAvailable = targetPrinter.isAvailable;
      
      return PrinterStatus(
        name: targetPrinter.name,
        isOnline: isAvailable,
        isAvailable: isAvailable,
        model: targetPrinter.model,
        error: isAvailable ? null : 'Printer not available',
      );
    } catch (e) {
      LoggerService.d('Printing', '[PrintingService] Printer check failed: $e');
      return PrinterStatus(
        name: printerName ?? 'default',
        isOnline: false,
        isAvailable: false,
        error: e.toString(),
      );
    }
  }

  /// P1 FIX: Process a print job
  Future<void> _processJob(PrintJob job) async {
    try {
      // Update status
      await _updateJob(job.copyWith(status: PrintJobStatus.printing));

      // Decode document
      final bytes = base64Decode(job.documentData);

      // Send to printer — bytes are the raw PDF, returned directly from callback
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${job.documentType}_${job.id}.pdf',
      );

      // Success
      final completedJob = job.copyWith(
        status: PrintJobStatus.completed,
        processedAt: DateTime.now(),
      );
      await _updateJob(completedJob);
      _jobController.add(completedJob);

      LoggerService.d('Printing', '[PrintingService] Job ${job.id} completed successfully');

    } catch (e) {
      LoggerService.d('Printing', '[PrintingService] Print failed: $e');
      
      final retryCount = job.retryCount + 1;
      
      if (retryCount >= _maxRetries) {
        // Max retries reached
        final failedJob = job.copyWith(
          status: PrintJobStatus.failed,
          errorMessage: e.toString(),
          processedAt: DateTime.now(),
          retryCount: retryCount,
        );
        await _updateJob(failedJob);
        _jobController.add(failedJob);
        _notifyUser('Print failed after $_maxRetries attempts. Please check printer.');
      } else {
        // Retry later
        final retryJob = job.copyWith(
          status: PrintJobStatus.offline,
          errorMessage: e.toString(),
          retryCount: retryCount,
        );
        await _updateJob(retryJob);
        _notifyUser('Print failed. Will retry in ${_retryDelay.inSeconds} seconds.');
      }
    }
  }

  /// P1 FIX: Start background queue processor
  void _startQueueProcessor() {
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        await _processPendingJobs();
      } finally {
        _isProcessing = false;
      }
    });
  }

  /// P1 FIX: Process all pending jobs
  Future<void> _processPendingJobs() async {
    final pendingJobs = await _getPendingJobs();
    
    if (pendingJobs.isEmpty) return;

    // Check printer status
    final firstJob = pendingJobs.first;
    final status = await _checkPrinterStatus(firstJob.printerName);

    if (!status.isOnline) {
      LoggerService.d('Printing', '[PrintingService] Printer still offline. ${pendingJobs.length} jobs pending.');
      return;
    }

    // Process each pending job
    for (final job in pendingJobs) {
      await _processJob(job);
      await Future.delayed(Duration(seconds: 2)); // Rate limiting
    }
  }

  /// Get all pending jobs
  Future<List<PrintJob>> _getPendingJobs() async {
    if (_box == null) return [];
    
    final jobs = <PrintJob>[];
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        try {
          final job = PrintJob.fromJson(Map<String, dynamic>.from(data));
          if (job.status == PrintJobStatus.queued || job.status == PrintJobStatus.offline) {
            jobs.add(job);
          }
        } catch (e) {
          LoggerService.d('Printing', '[PrintingService] Failed to parse job $key: $e');
        }
      }
    }
    
    // Sort by creation time
    jobs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return jobs;
  }

  /// Save job to storage
  Future<void> _saveJob(PrintJob job) async {
    await _box?.put(job.id, job.toJson());
    _jobController.add(job);
  }

  /// Update job in storage
  Future<void> _updateJob(PrintJob job) async {
    await _box?.put(job.id, job.toJson());
  }

  /// Get print statistics
  Future<Map<String, dynamic>> getStats() async {
    if (_box == null) await init();
    
    int total = 0;
    int completed = 0;
    int failed = 0;
    int pending = 0;
    int offline = 0;

    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        try {
          final job = PrintJob.fromJson(Map<String, dynamic>.from(data));
          total++;
          switch (job.status) {
            case PrintJobStatus.completed:
              completed++;
              break;
            case PrintJobStatus.failed:
              failed++;
              break;
            case PrintJobStatus.queued:
              pending++;
              break;
            case PrintJobStatus.offline:
              offline++;
              break;
            default:
              break;
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
    }

    return {
      'total': total,
      'completed': completed,
      'failed': failed,
      'pending': pending,
      'offline': offline,
    };
  }

  /// Retry a failed job
  Future<void> retryJob(String jobId) async {
    final data = _box?.get(jobId);
    if (data == null) return;

    final job = PrintJob.fromJson(Map<String, dynamic>.from(data));
    
    final resetJob = job.copyWith(
      status: PrintJobStatus.queued,
      errorMessage: null,
      retryCount: 0,
    );
    
    await _updateJob(resetJob);
    await _processJob(resetJob);
  }

  /// Cancel a pending job
  Future<void> cancelJob(String jobId) async {
    final data = _box?.get(jobId);
    if (data == null) return;

    final job = PrintJob.fromJson(Map<String, dynamic>.from(data));
    
    if (job.status == PrintJobStatus.queued || job.status == PrintJobStatus.offline) {
      final cancelledJob = job.copyWith(
        status: PrintJobStatus.cancelled,
        processedAt: DateTime.now(),
      );
      await _updateJob(cancelledJob);
      _jobController.add(cancelledJob);
    }
  }

  /// Clear old completed jobs
  Future<void> clearOldJobs(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    
    final keysToDelete = <String>[];
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        try {
          final job = PrintJob.fromJson(Map<String, dynamic>.from(data));
          if (job.createdAt.isBefore(cutoff) && 
              (job.status == PrintJobStatus.completed || job.status == PrintJobStatus.cancelled)) {
            keysToDelete.add(key);
          }
        } catch (e) {
          keysToDelete.add(key); // Delete invalid entries
        }
      }
    }

    for (final key in keysToDelete) {
      await _box?.delete(key);
    }
  }

  void _notifyUser(String message) {
    // This would show a SnackBar in the UI
    LoggerService.d('Printing', '[PrintingService] User notification: $message');
  }

  /// Dispose
  void dispose() {
    _queueTimer?.cancel();
    _statusController.close();
    _jobController.close();
    _box?.close();
  }
}

// Singleton instance
final printingService = PrintingService();
