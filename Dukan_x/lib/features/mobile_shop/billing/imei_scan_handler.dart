/// IMEI Scan Handler — Scan-to-Bill Integration for MobileShop Billing
///
/// Handles barcode/QR scanner results for IMEI entry: normalizes scanned
/// values, validates them, rejects duplicates already in the bill, provides
/// a manual fallback when scanner fails, and prevents busy-state duplicates
/// with a configurable cooldown.
///
/// Requirements: 2.5, 3.1–3.2, 10.3, 11.7–11.8, 12.1–12.2
/// Audit: AF-20
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/imei_validator.dart';
import 'imei_field_controller.dart';
import 'mobile_sale_imei_validator.dart';

// ─── Scan Result ─────────────────────────────────────────────────────────────

/// Result of processing a scanned IMEI value.
sealed class ScanResult {
  const ScanResult();
}

/// Scan was valid and accepted.
@immutable
class ScanAccepted extends ScanResult {
  final NormalizedImei imei;
  const ScanAccepted(this.imei);
}

/// Scan was rejected due to validation failure.
@immutable
class ScanValidationError extends ScanResult {
  final String message;
  final ImeiValidationErrorCode? code;
  const ScanValidationError({required this.message, this.code});
}

/// Scan was rejected because the IMEI is already in the bill.
@immutable
class ScanDuplicateRejected extends ScanResult {
  final String imei;
  const ScanDuplicateRejected(this.imei);
}

/// Scan was rejected because the handler is still in cooldown.
@immutable
class ScanBusyRejected extends ScanResult {
  const ScanBusyRejected();
}

// ─── Handler ─────────────────────────────────────────────────────────────────

/// Handles scan-to-bill IMEI integration.
///
/// Responsibilities:
/// - Normalize and validate scanned values
/// - Reject duplicates already in the current bill
/// - Debounce rapid scans (500ms cooldown)
/// - Signal manual fallback when scanner fails
class ImeiScanHandler extends ChangeNotifier {
  final MobileSaleImeiValidator _validator;
  final ImeiFieldController _fieldController;

  /// Cooldown duration between scans to prevent busy duplicates.
  static const Duration _scanCooldown = Duration(milliseconds: 500);

  /// Minimum touch target size for scan button (logical pixels).
  static const double minTouchTarget = 48.0;

  bool _isCoolingDown = false;
  Timer? _cooldownTimer;

  /// Whether manual fallback mode is active (scanner failed/unavailable).
  bool _manualFallbackActive = false;
  bool get manualFallbackActive => _manualFallbackActive;

  /// The last scan error message for inline display.
  String? _lastScanError;
  String? get lastScanError => _lastScanError;

  /// Whether the handler is currently in cooldown (busy).
  bool get isBusy => _isCoolingDown;

  // ─── Constructor ─────────────────────────────────────────────────────────

  /// Creates a scan handler bound to the given validator and field controller.
  ImeiScanHandler({
    required MobileSaleImeiValidator validator,
    required ImeiFieldController fieldController,
  }) : _validator = validator,
       _fieldController = fieldController;

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Processes a scanned IMEI value from barcode/QR scanner.
  ///
  /// Returns [ScanResult] indicating the outcome:
  /// - [ScanAccepted]: valid, unique, and added to the field
  /// - [ScanValidationError]: IMEI failed validation
  /// - [ScanDuplicateRejected]: IMEI already in the bill
  /// - [ScanBusyRejected]: cooldown active, scan ignored
  ScanResult handleScanResult(String scannedValue, List<String> existingImeis) {
    // Prevent rapid duplicate scans
    if (_isCoolingDown) {
      return const ScanBusyRejected();
    }

    // Start cooldown
    _startCooldown();

    // Set field controller busy
    _fieldController.setBusy(true);

    try {
      // Normalize: trim whitespace that scanners sometimes add
      final trimmed = scannedValue.trim();

      // Check for duplicates first (fast path)
      final duplicateError = _fieldController.preventDuplicateScan(
        trimmed,
        existingImeis,
      );
      if (duplicateError != null) {
        _lastScanError = 'This IMEI is already in the bill';
        notifyListeners();
        return ScanDuplicateRejected(trimmed);
      }

      // Validate through the authoritative path
      final result = _validator.validateForSale(trimmed);

      switch (result) {
        case ImeiValidationSuccess(:final value):
          _lastScanError = null;
          _fieldController.validate(trimmed);
          notifyListeners();
          return ScanAccepted(value);

        case ImeiValidationFailure(:final error):
          _lastScanError = error.message;
          _fieldController.validate(trimmed);
          notifyListeners();
          return ScanValidationError(message: error.message, code: error.code);
      }
    } finally {
      _fieldController.setBusy(false);
    }
  }

  /// Checks if the given IMEI is a duplicate in the current bill.
  bool isDuplicate(String imei, List<String> existingImeis) {
    final normalized = imei.replaceAll(RegExp(r'[\s\-.]'), '');
    for (final existing in existingImeis) {
      final normalizedExisting = existing.replaceAll(RegExp(r'[\s\-.]'), '');
      if (normalized == normalizedExisting) {
        return true;
      }
    }
    return false;
  }

  /// Shows inline duplicate-rejection error.
  void showDuplicateRejection() {
    _lastScanError = 'This IMEI is already in the bill';
    notifyListeners();
  }

  /// Activates manual fallback when the scanner fails or is unavailable.
  ///
  /// This enables manual IMEI text entry as an alternative to scanning.
  void showManualFallback() {
    _manualFallbackActive = true;
    _lastScanError = null;
    notifyListeners();
  }

  /// Hides manual fallback (returns to scanner mode).
  void hideManualFallback() {
    _manualFallbackActive = false;
    notifyListeners();
  }

  /// Clears the last scan error.
  void clearError() {
    _lastScanError = null;
    notifyListeners();
  }

  /// Resets the handler to its initial state.
  void reset() {
    _cooldownTimer?.cancel();
    _isCoolingDown = false;
    _manualFallbackActive = false;
    _lastScanError = null;
    notifyListeners();
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  /// Starts the cooldown timer to prevent rapid duplicate scans.
  void _startCooldown() {
    _isCoolingDown = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_scanCooldown, () {
      _isCoolingDown = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
