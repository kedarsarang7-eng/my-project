import 'package:flutter/material.dart';
// import '../../features/accounting/services/locking_service.dart'; // For PeriodLockException if exported
import '../error/credit_limit_exception.dart';
import '../sync/sync_conflict.dart';

/// Model for a user-friendly error display
class UserFriendlyError {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const UserFriendlyError({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

/// Mapper to convert raw exceptions into UI-friendly models
class ExceptionMapper {
  static UserFriendlyError map(dynamic error) {
    final String errorStr = error.toString();

    // 1. Credit Limit
    if (error is CreditLimitExceededException) {
      return UserFriendlyError(
        title: 'Credit Limit Reached',
        message:
            'This sale exceeds the customer limit of ₹${error.creditLimit}. \n\nCurrent Dues: ₹${error.currentDues}',
        icon: Icons.block,
        color: Colors.red,
      );
    }

    // Fallback for string matching if exception type is lost
    if (errorStr.contains('Credit Limit Exceeded')) {
      return const UserFriendlyError(
        title: 'Credit Limit Reached',
        message: 'Sale blocked because customer credit limit is exceeded.',
        icon: Icons.block,
        color: Colors.red,
      );
    }

    // 2. Period Locking (Accounting)
    if (errorStr.contains('PeriodLocked') ||
        errorStr.contains('Accounting period is locked')) {
      return const UserFriendlyError(
        title: 'Period Locked',
        message:
            'You cannot edit records in a closed accounting period (Month End Closed). \n\nPlease contact the admin to unlock.',
        icon: Icons.lock_clock,
        color: Colors.orange,
      );
    }

    // 3. Negative Stock
    if (errorStr.contains('Insufficient Stock') ||
        errorStr.contains('Negative stock is disabled')) {
      return const UserFriendlyError(
        title: 'Insufficient Stock',
        message:
            'You are trying to sell more than available stock. Negative stock is disabled.',
        icon: Icons.inventory_2,
        color: Colors.orangeAccent,
      );
    }

    // 4. Traceability / Sync Conflicts
    if (error is SyncConflictException || errorStr.contains('SyncConflict')) {
      return const UserFriendlyError(
        title: 'Sync Conflict',
        message:
            'This record was modified on another device. Please refresh and try again.',
        icon: Icons.cloud_off,
        color: Colors.amber,
      );
    }

    // 5. Concurrent Modification
    if (errorStr.contains('Concurrent edit detected')) {
      return const UserFriendlyError(
        title: 'Data Changed',
        message:
            'Another user updated this bill while you were viewing it. Please reopen the bill.',
        icon: Icons.refresh,
        color: Colors.blue,
      );
    }

    // 6. Generic Network
    if (errorStr.contains('SocketException') || errorStr.contains('Network')) {
      return const UserFriendlyError(
        title: 'Network Error',
        message: 'Please check your internet connection.',
        icon: Icons.wifi_off,
        color: Colors.grey,
      );
    }

    // Default Fallback
    return UserFriendlyError(
      title: 'Action Failed',
      message: _cleanMessage(errorStr),
      icon: Icons.error_outline,
      color: Colors.redAccent,
    );
  }

  static String _cleanMessage(String raw) {
    if (raw.startsWith('Exception: ')) return raw.substring(11);
    // Truncate if too long
    if (raw.length > 200) return '${raw.substring(0, 200)}...';
    return raw;
  }
}
