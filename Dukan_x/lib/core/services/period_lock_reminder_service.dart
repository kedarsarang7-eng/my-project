// ============================================================================
// PERIOD LOCK REMINDER SERVICE - Control 3
// ============================================================================
// Notifies users when month-end approaches without period closure.
// Supports in-app notifications and optional push/email hooks.
//
// ============================================================================
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

/// Period Lock Reminder Service
/// Checks for unclosed accounting periods and generates reminders
class PeriodLockReminderService {
  /// Check for unclosed periods and return reminder if needed
  ///
  /// Returns a reminder if:
  /// - Current date is >= 25th of month (approaching month-end)
  /// - Previous month is not locked
  /// - Current month is ending in <= 5 days
  Future<PeriodLockReminder?> checkForReminder({
    required String userId,
    required Future<DateTime?> Function(String userId) getLockDate,
    DateTime? now,
  }) async {
    final currentDate = now ?? DateTime.now();
    final currentDay = currentDate.day;
    final daysInMonth = DateTime(
      currentDate.year,
      currentDate.month + 1,
      0,
    ).day;
    final daysRemaining = daysInMonth - currentDay;

    // Check if we're approaching month-end (last 5 days)
    if (daysRemaining > 5) {
      return null; // Not yet time to remind
    }

    // Get current lock date
    final lockDate = await getLockDate(userId);

    // Calculate previous month
    final previousMonth = currentDate.month == 1
        ? DateTime(currentDate.year - 1, 12, 31)
        : DateTime(
            currentDate.year,
            currentDate.month - 1,
            DateTime(currentDate.year, currentDate.month, 0).day,
          );

    // Check if previous month is locked
    final isPreviousMonthLocked =
        lockDate != null &&
        (lockDate.isAfter(previousMonth) ||
            lockDate.isAtSameMomentAs(previousMonth));

    if (!isPreviousMonthLocked) {
      // Previous month is NOT locked - generate reminder
      return PeriodLockReminder(
        userId: userId,
        reminderType: PeriodReminderType.previousMonthOpen,
        month: previousMonth.month,
        year: previousMonth.year,
        daysRemaining: daysRemaining,
        message: _generateMessage(previousMonth, daysRemaining),
        priority: daysRemaining <= 2
            ? ReminderPriority.high
            : ReminderPriority.medium,
        createdAt: currentDate,
      );
    }

    // Check if current month is about to end and not locked
    if (daysRemaining <= 2) {
      // Approaching month-end
      return PeriodLockReminder(
        userId: userId,
        reminderType: PeriodReminderType.monthEndApproaching,
        month: currentDate.month,
        year: currentDate.year,
        daysRemaining: daysRemaining,
        message:
            'Month ending in $daysRemaining days. Remember to close your books.',
        priority: ReminderPriority.low,
        createdAt: currentDate,
      );
    }

    return null;
  }

  /// Check if reminder should be shown to user
  /// Returns true if user hasn't dismissed today's reminder
  bool shouldShowReminder({required DateTime? lastDismissedAt, DateTime? now}) {
    if (lastDismissedAt == null) return true;

    final currentDate = now ?? DateTime.now();
    final today = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final dismissedDay = DateTime(
      lastDismissedAt.year,
      lastDismissedAt.month,
      lastDismissedAt.day,
    );

    // Show reminder once per day
    return today.isAfter(dismissedDay);
  }

  /// Generate user-friendly reminder message
  String _generateMessage(DateTime month, int daysRemaining) {
    final monthName = _getMonthName(month.month);
    final year = month.year;

    if (daysRemaining <= 1) {
      return '⚠️ URGENT: $monthName $year books are still open. '
          'Lock the period to prevent accidental modifications.';
    } else if (daysRemaining <= 3) {
      return '📅 Reminder: $monthName $year period is not locked. '
          'Please review and lock before month-end.';
    } else {
      return '📆 $monthName $year period is still open. '
          'Consider locking it for audit compliance.';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  /// Get all unclosed periods for a user
  Future<List<UnclosedPeriod>> getUnclosedPeriods({
    required String userId,
    required DateTime? lockDate,
    required DateTime businessStartDate,
    DateTime? now,
  }) async {
    final currentDate = now ?? DateTime.now();
    final unclosed = <UnclosedPeriod>[];

    // Start from business start month
    var checkDate = DateTime(
      businessStartDate.year,
      businessStartDate.month,
      1,
    );

    // Check each month until previous month
    while (checkDate.isBefore(
      DateTime(currentDate.year, currentDate.month, 1),
    )) {
      final monthEnd = DateTime(checkDate.year, checkDate.month + 1, 0);

      // Check if this month is locked
      final isLocked =
          lockDate != null &&
          (lockDate.isAfter(monthEnd) || lockDate.isAtSameMomentAs(monthEnd));

      if (!isLocked) {
        unclosed.add(
          UnclosedPeriod(
            month: checkDate.month,
            year: checkDate.year,
            monthName: _getMonthName(checkDate.month),
            startDate: checkDate,
            endDate: monthEnd,
          ),
        );
      }

      // Move to next month
      checkDate = DateTime(checkDate.year, checkDate.month + 1, 1);
    }

    return unclosed;
  }
}

// ============================================================
// DATA CLASSES
// ============================================================

/// Period lock reminder data
class PeriodLockReminder {
  final String userId;
  final PeriodReminderType reminderType;
  final int month;
  final int year;
  final int daysRemaining;
  final String message;
  final ReminderPriority priority;
  final DateTime createdAt;

  PeriodLockReminder({
    required this.userId,
    required this.reminderType,
    required this.month,
    required this.year,
    required this.daysRemaining,
    required this.message,
    required this.priority,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'reminderType': reminderType.name,
    'month': month,
    'year': year,
    'daysRemaining': daysRemaining,
    'message': message,
    'priority': priority.name,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Unclosed period information
class UnclosedPeriod {
  final int month;
  final int year;
  final String monthName;
  final DateTime startDate;
  final DateTime endDate;

  UnclosedPeriod({
    required this.month,
    required this.year,
    required this.monthName,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'month': month,
    'year': year,
    'monthName': monthName,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
  };
}

/// Types of period reminders
enum PeriodReminderType {
  previousMonthOpen,
  monthEndApproaching,
  multiplePeriodsOpen,
}

/// Reminder priority levels
enum ReminderPriority { low, medium, high }
