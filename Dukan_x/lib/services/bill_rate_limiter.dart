// ============================================================================
// BILL RATE LIMITER - Control 5
// ============================================================================
// Prevents mass bill generation attacks by implementing per-user/per-business
// rate limiting with soft warnings and hard blocks.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/foundation.dart';

/// Bill Rate Limiter Service
/// Prevents fraud via mass bill generation
class BillRateLimiter {
  // Configuration
  static const int softLimitBills = 50;
  static const int hardLimitBills = 100;
  static const Duration windowDuration = Duration(minutes: 10);

  // In-memory rate tracking (per user)
  // In production, this should be persisted or use a proper rate limiting service
  final Map<String, List<DateTime>> _userBillTimestamps = {};

  /// Check if user is within rate limits
  /// Returns result with status and remaining quota
  RateLimitResult checkRateLimit(String userId) {
    _cleanupOldEntries(userId);

    final timestamps = _userBillTimestamps[userId] ?? [];
    final billCount = timestamps.length;

    if (billCount >= hardLimitBills) {
      return RateLimitResult(
        status: RateLimitStatus.blocked,
        currentCount: billCount,
        softLimit: softLimitBills,
        hardLimit: hardLimitBills,
        remainingInWindow: 0,
        windowResetAt: _getWindowResetTime(userId),
        message:
            'Rate limit exceeded. You have created $billCount bills in the last 10 minutes. '
            'Please wait before creating more bills.',
      );
    }

    if (billCount >= softLimitBills) {
      return RateLimitResult(
        status: RateLimitStatus.warning,
        currentCount: billCount,
        softLimit: softLimitBills,
        hardLimit: hardLimitBills,
        remainingInWindow: hardLimitBills - billCount,
        windowResetAt: _getWindowResetTime(userId),
        message:
            'Warning: You are approaching the rate limit. '
            '${hardLimitBills - billCount} bills remaining in this window.',
      );
    }

    return RateLimitResult(
      status: RateLimitStatus.allowed,
      currentCount: billCount,
      softLimit: softLimitBills,
      hardLimit: hardLimitBills,
      remainingInWindow: hardLimitBills - billCount,
      windowResetAt: _getWindowResetTime(userId),
    );
  }

  /// Record a bill creation event
  void recordBillCreation(String userId) {
    _userBillTimestamps.putIfAbsent(userId, () => []);
    _userBillTimestamps[userId]!.add(DateTime.now());

    debugPrint(
      'BillRateLimiter: Recorded bill for $userId. Count: ${_userBillTimestamps[userId]!.length}',
    );
  }

  /// Clean up timestamps outside the window
  void _cleanupOldEntries(String userId) {
    final now = DateTime.now();
    final windowStart = now.subtract(windowDuration);

    _userBillTimestamps[userId] = (_userBillTimestamps[userId] ?? [])
        .where((timestamp) => timestamp.isAfter(windowStart))
        .toList();
  }

  /// Get when the rate limit window resets
  DateTime _getWindowResetTime(String userId) {
    final timestamps = _userBillTimestamps[userId];
    if (timestamps == null || timestamps.isEmpty) {
      return DateTime.now();
    }

    // Window resets when oldest entry expires
    final oldestTimestamp = timestamps.reduce((a, b) => a.isBefore(b) ? a : b);
    return oldestTimestamp.add(windowDuration);
  }

  /// Get current usage stats for a user
  RateLimitStats getStats(String userId) {
    _cleanupOldEntries(userId);

    final timestamps = _userBillTimestamps[userId] ?? [];

    return RateLimitStats(
      userId: userId,
      billsInWindow: timestamps.length,
      softLimit: softLimitBills,
      hardLimit: hardLimitBills,
      windowDurationMinutes: windowDuration.inMinutes,
      oldestBillInWindow: timestamps.isEmpty
          ? null
          : timestamps.reduce((a, b) => a.isBefore(b) ? a : b),
      newestBillInWindow: timestamps.isEmpty
          ? null
          : timestamps.reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  /// Reset rate limit for a user (admin function)
  void resetUserLimit(String userId) {
    _userBillTimestamps.remove(userId);
    debugPrint('BillRateLimiter: Reset limit for $userId');
  }

  /// Clear all rate limits (for testing)
  @visibleForTesting
  void clearAll() {
    _userBillTimestamps.clear();
  }
}

// ============================================================
// RESULT CLASSES
// ============================================================

/// Result of rate limit check
class RateLimitResult {
  final RateLimitStatus status;
  final int currentCount;
  final int softLimit;
  final int hardLimit;
  final int remainingInWindow;
  final DateTime windowResetAt;
  final String? message;

  RateLimitResult({
    required this.status,
    required this.currentCount,
    required this.softLimit,
    required this.hardLimit,
    required this.remainingInWindow,
    required this.windowResetAt,
    this.message,
  });

  bool get isAllowed => status == RateLimitStatus.allowed;
  bool get isWarning => status == RateLimitStatus.warning;
  bool get isBlocked => status == RateLimitStatus.blocked;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'currentCount': currentCount,
    'softLimit': softLimit,
    'hardLimit': hardLimit,
    'remainingInWindow': remainingInWindow,
    'windowResetAt': windowResetAt.toIso8601String(),
    if (message != null) 'message': message,
  };
}

/// Rate limit usage statistics
class RateLimitStats {
  final String userId;
  final int billsInWindow;
  final int softLimit;
  final int hardLimit;
  final int windowDurationMinutes;
  final DateTime? oldestBillInWindow;
  final DateTime? newestBillInWindow;

  RateLimitStats({
    required this.userId,
    required this.billsInWindow,
    required this.softLimit,
    required this.hardLimit,
    required this.windowDurationMinutes,
    this.oldestBillInWindow,
    this.newestBillInWindow,
  });

  double get utilizationPercent => (billsInWindow / hardLimit) * 100;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'billsInWindow': billsInWindow,
    'softLimit': softLimit,
    'hardLimit': hardLimit,
    'windowDurationMinutes': windowDurationMinutes,
    'utilizationPercent': utilizationPercent.toStringAsFixed(1),
    if (oldestBillInWindow != null)
      'oldestBillInWindow': oldestBillInWindow!.toIso8601String(),
    if (newestBillInWindow != null)
      'newestBillInWindow': newestBillInWindow!.toIso8601String(),
  };
}

/// Rate limit status levels
enum RateLimitStatus {
  allowed, // Under soft limit - proceed normally
  warning, // Between soft and hard limit - show warning but allow
  blocked, // At or above hard limit - reject
}
