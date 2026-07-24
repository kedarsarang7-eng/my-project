/// IMEI Field Controller — Required Field Behavior for MobileShop Billing
///
/// Controls IMEI field validation, required-field semantics, duplicate-scan
/// rejection, busy-state duplicate prevention, and preservation of valid
/// line-item input on validation failure of a single field.
///
/// This controller uses [MobileSaleImeiValidator] for authoritative validation
/// and enforces `isRequired: true` for mobileShop tenants (config-driven).
///
/// Requirements: 2.5, 3.1–3.2, 10.3, 11.7–11.8, 12.1–12.2
/// Audit: AF-20
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/imei_validator.dart';
import 'mobile_sale_imei_validator.dart';

// ─── Controller ──────────────────────────────────────────────────────────────

/// Controls IMEI field behavior in the mobileShop billing UI.
///
/// Responsibilities:
/// - Required-field enforcement (always true for mobileShop)
/// - Live validation with debounce (200ms)
/// - Duplicate-scan rejection against current bill lines
/// - Busy-state duplicate prevention during rapid scans
/// - Preservation of valid line items when one field fails
class ImeiFieldController extends ChangeNotifier {
  final MobileSaleImeiValidator _validator;

  /// Debounce duration for live validation on text change.
  static const Duration _debounceDuration = Duration(milliseconds: 200);

  Timer? _debounceTimer;

  // ─── Reactive state ──────────────────────────────────────────────────────

  /// Whether this IMEI field is required. Always true for mobileShop.
  bool get isRequired => true;

  /// Current field-associated error message (null when valid or untouched).
  String? _fieldError;
  String? get fieldError => _fieldError;

  /// Current field-associated error code (null when valid or untouched).
  ImeiValidationErrorCode? _errorCode;
  ImeiValidationErrorCode? get errorCode => _errorCode;

  /// Whether the field is currently in a busy state (preventing duplicates).
  bool _busyState = false;
  bool get busyState => _busyState;

  /// The last successfully validated IMEI value.
  NormalizedImei? _validatedImei;
  NormalizedImei? get validatedImei => _validatedImei;

  // ─── Constructor ─────────────────────────────────────────────────────────

  /// Creates a controller bound to the given [MobileSaleImeiValidator].
  ImeiFieldController({required MobileSaleImeiValidator validator})
    : _validator = validator;

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Validates the given IMEI value synchronously.
  ///
  /// Returns a user-facing error string if invalid, or null if valid.
  /// Updates [fieldError] and [errorCode] reactively.
  String? validate(String? value) {
    final result = _validator.validateForSale(value);

    switch (result) {
      case ImeiValidationSuccess(:final value):
        _fieldError = null;
        _errorCode = null;
        _validatedImei = value;
        notifyListeners();
        return null;

      case ImeiValidationFailure(:final error):
        _fieldError = error.message;
        _errorCode = error.code;
        _validatedImei = null;
        notifyListeners();
        return error.message;
    }
  }

  /// Called on every text change. Debounces validation by [_debounceDuration].
  ///
  /// This provides inline live feedback without excessive validation calls.
  void onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      // Only validate non-empty input on change — empty is caught on submit
      if (value.trim().isNotEmpty) {
        validate(value);
      } else {
        // Clear error when user empties the field (submit will catch it)
        _fieldError = null;
        _errorCode = null;
        _validatedImei = null;
        notifyListeners();
      }
    });
  }

  /// Checks if the given IMEI is already present in the bill's existing lines.
  ///
  /// Returns an error message if duplicate, or null if unique.
  /// Normalizes both the input and existing IMEIs for comparison.
  String? preventDuplicateScan(String imei, List<String> existingImeis) {
    // Normalize the incoming IMEI for comparison
    final result = _validator.validateForSale(imei);
    String normalizedInput;

    switch (result) {
      case ImeiValidationSuccess(:final value):
        normalizedInput = value.value;
      case ImeiValidationFailure():
        // If validation fails, the caller should handle that separately.
        // We still check raw duplicate to prevent obvious duplicates.
        normalizedInput = imei.replaceAll(RegExp(r'[\s\-.]'), '');
    }

    // Check against existing bill lines
    for (final existing in existingImeis) {
      final normalizedExisting = existing.replaceAll(RegExp(r'[\s\-.]'), '');
      if (normalizedInput == normalizedExisting) {
        const errorMsg = 'This IMEI is already in the bill';
        _fieldError = errorMsg;
        _errorCode = null; // Not a standard validation error code
        notifyListeners();
        return errorMsg;
      }
    }

    return null;
  }

  /// Preserves valid line-item input when one field fails validation.
  ///
  /// Call this to indicate that despite an error on THIS field, other valid
  /// line items in the bill should not be cleared or reset. This method
  /// does NOT clear the current error — it signals preservation of siblings.
  ///
  /// Returns true if this field currently has a valid IMEI.
  bool preserveValidInput() {
    return _validatedImei != null;
  }

  /// Sets the busy state to prevent rapid duplicate submissions.
  ///
  /// While busy, the field should visually indicate processing and reject
  /// additional scan/submit attempts.
  void setBusy(bool busy) {
    if (_busyState != busy) {
      _busyState = busy;
      notifyListeners();
    }
  }

  /// Clears the current error and validation state.
  void clearError() {
    _fieldError = null;
    _errorCode = null;
    notifyListeners();
  }

  /// Resets the controller to its initial state.
  void reset() {
    _debounceTimer?.cancel();
    _fieldError = null;
    _errorCode = null;
    _busyState = false;
    _validatedImei = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
