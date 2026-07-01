// ============================================================================
// License Write Block Service — Singleton
// ============================================================================
// Phase 4 NEW FEATURE: Centralized write-blocking for expired/readOnly licenses.
//
// All service layer mutations should check `LicenseWriteBlockService.isBlocked`
// before performing any write operations. This prevents data mutations during
// expired license grace periods (readOnly mode).
//
// Usage:
//   if (LicenseWriteBlockService.instance.isBlocked) {
//     throw LicenseWriteBlockedException();
//   }
//   // proceed with write...
// ============================================================================

import '../../../core/services/logger_service.dart';

/// Exception thrown when a write operation is attempted while license is blocked.
class LicenseWriteBlockedException implements Exception {
  final String message;
  const LicenseWriteBlockedException([
    this.message = 'Write operations are blocked. License expired or in read-only mode.',
  ]);

  @override
  String toString() => 'LicenseWriteBlockedException: $message';
}

/// Singleton service that tracks whether write operations should be blocked.
///
/// This is set by [LicenseMiddleware] when the license state is [readOnly],
/// and cleared when the license is revalidated as active.
class LicenseWriteBlockService {
  LicenseWriteBlockService._();
  static final LicenseWriteBlockService _instance = LicenseWriteBlockService._();
  static LicenseWriteBlockService get instance => _instance;

  bool _isBlocked = false;
  String? _reason;
  DateTime? _blockedSince;

  /// Whether write operations are currently blocked.
  bool get isBlocked => _isBlocked;

  /// Human-readable reason for the block (e.g., 'License expired').
  String? get reason => _reason;

  /// When the block was activated.
  DateTime? get blockedSince => _blockedSince;

  /// Block all write operations. Called by LicenseMiddleware.
  void block({String reason = 'License expired or in read-only mode'}) {
    if (!_isBlocked) {
      _isBlocked = true;
      _reason = reason;
      _blockedSince = DateTime.now();
      LoggerService.d('LicenseWriteBlock', 'LicenseWriteBlock: BLOCKED — $reason');
    }
  }

  /// Unblock write operations. Called when license is revalidated as active.
  void unblock() {
    if (_isBlocked) {
      _isBlocked = false;
      _reason = null;
      _blockedSince = null;
      LoggerService.d('LicenseWriteBlock', 'LicenseWriteBlock: UNBLOCKED');
    }
  }

  /// Guard method — throws [LicenseWriteBlockedException] if blocked.
  /// Use at the top of any service method that performs mutations.
  void guardWrite() {
    if (_isBlocked) {
      throw LicenseWriteBlockedException(_reason ?? 'Write blocked');
    }
  }
}
