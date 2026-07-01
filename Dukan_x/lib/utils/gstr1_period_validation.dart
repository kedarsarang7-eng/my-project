/// GSTR-1 Return Period Validation
/// 
/// Validates that GSTR-1 returns cover exactly one calendar month
/// and do not include amended/duplicate invoices.
library;

import 'package:intl/intl.dart';

/// Represents a valid GST return period (exactly one calendar month)
class GstrReturnPeriod {
  final DateTime periodStart;  // 1st of month, 00:00:00 IST
  final DateTime periodEnd;    // Last day of month, 23:59:59 IST
  final int month;             // 1-12
  final int year;              // YYYY

  GstrReturnPeriod({
    required this.periodStart,
    required this.periodEnd,
    required this.month,
    required this.year,
  });

  /// Create period for a specific calendar month
  /// 
  /// Month: 1-12
  /// Year: YYYY (e.g., 2026)
  factory GstrReturnPeriod.forMonth(int month, int year) {
    if (month < 1 || month > 12) {
      throw GstrPeriodException('Month must be 1-12, got: $month');
    }
    if (year < 2000 || year > 2100) {
      throw GstrPeriodException('Year must be 2000-2100, got: $year');
    }

    // First day of the month at 00:00:00 IST
    final start = DateTime(year, month, 1);
    
    // Last day of the month at 23:59:59 IST
    // DateTime constructor handles month overflow (13 â†’ next year)
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    return GstrReturnPeriod(
      periodStart: start,
      periodEnd: end,
      month: month,
      year: year,
    );
  }

  /// Create period from a date (extracts month/year)
  factory GstrReturnPeriod.fromDate(DateTime date) {
    return GstrReturnPeriod.forMonth(date.month, date.year);
  }

  /// Get period in GST Portal format (MMYYYY)
  /// 
  /// Examples:
  /// - April 2026 â†’ "042026"
  /// - January 2026 â†’ "012026"
  String get periodCode {
    final monthStr = month.toString().padLeft(2, '0');
    return '$monthStr$year';
  }

  /// Check if a date is within this return period
  bool contains(DateTime date) {
    return date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
           date.isBefore(periodEnd.add(const Duration(seconds: 1)));
  }

  /// Format period for display
  /// 
  /// Example: "April 2026" or "1-30 April 2026"
  String get displayText {
    final formatter = DateFormat('MMMM yyyy', 'en_US');
    return formatter.format(periodStart);
  }

  @override
  String toString() => 'GstrReturnPeriod($month/$year: ${periodStart.toIso8601String()} to ${periodEnd.toIso8601String()})';
}

/// Validates GSTR-1 filing criteria
class GstrReturnValidator {
  /// Validate that dates form exactly one calendar month
  /// 
  /// Throws if:
  /// - From date is not the 1st of the month
  /// - To date is not the last day of the month
  /// - From/To span multiple months
  static GstrReturnPeriod validatePeriod(DateTime fromDate, DateTime toDate) {
    // Normalize to midnight
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day);

    // Check: from date must be 1st of month
    if (from.day != 1) {
      throw GstrPeriodException(
        'GSTR-1 period must start on the 1st of month. '
        'Got: ${from.toIso8601String()}',
      );
    }

    // Check: to date must be last day of month
    final lastDayOfMonth = DateTime(to.year, to.month + 1, 0).day;
    if (to.day != lastDayOfMonth) {
      throw GstrPeriodException(
        'GSTR-1 period must end on last day of month ($lastDayOfMonth). '
        'Got: ${to.toIso8601String()}',
      );
    }

    // Check: from and to must be in same month
    if (from.month != to.month || from.year != to.year) {
      throw GstrPeriodException(
        'GSTR-1 period must cover exactly one calendar month. '
        'Got: ${from.toIso8601String()} to ${to.toIso8601String()} '
        '(spans ${from.month}/${from.year} to ${to.month}/${to.year})',
      );
    }

    return GstrReturnPeriod.forMonth(from.month, from.year);
  }

  /// Deduplicate invoices (keep latest amendment)
  /// 
  /// If same invoice ID has multiple versions (amendments),
  /// keep only the latest (highest amendment number).
  /// 
  /// Returns deduplicated list.
  static List<Map<String, dynamic>> deduplicateAmendedInvoices(
    List<Map<String, dynamic>> invoices,
  ) {
    final deduped = <String, Map<String, dynamic>>{};

    for (final invoice in invoices) {
      final invoiceId = invoice['invoiceId'] as String?;
      if (invoiceId == null) continue;

      final amendmentNum = invoice['amendmentNumber'] as int? ?? 0;
      final existing = deduped[invoiceId];

      if (existing == null) {
        deduped[invoiceId] = invoice;
      } else {
        final existingAmendment = existing['amendmentNumber'] as int? ?? 0;
        if (amendmentNum > existingAmendment) {
          deduped[invoiceId] = invoice;
        }
      }
    }

    return deduped.values.toList();
  }

  /// Verify no gaps in invoice numbering
  /// 
  /// Checks that invoice numbers form a sequential series.
  /// Allows for voids if documented.
  static Map<String, dynamic> verifyGaplessSequence(
    List<String> invoiceNumbers,
    Map<String, String>? voidedInvoices,  // number â†’ void reason
  ) {
    final gaps = <String>[];
    final reasons = <String, String>{};

    // Sort numerically
    final sorted = <int>[];
    for (final numStr in invoiceNumbers) {
      try {
        sorted.add(int.parse(numStr));
      } catch (e) {
        // Non-numeric invoice number, skip
      }
    }
    sorted.sort();

    // Find gaps
    for (int i = 0; i < sorted.length - 1; i++) {
      final current = sorted[i];
      final next = sorted[i + 1];

      if (next - current > 1) {
        // Gap found
        for (int g = current + 1; g < next; g++) {
          final gapNum = g.toString();
          gaps.add(gapNum);

          // Check if voided
          if (voidedInvoices != null && voidedInvoices.containsKey(gapNum)) {
            reasons[gapNum] = voidedInvoices[gapNum]!;
          } else {
            reasons[gapNum] = 'NOT DOCUMENTED';
          }
        }
      }
    }

    return {
      'hasGaps': gaps.isNotEmpty,
      'gapCount': gaps.length,
      'gaps': gaps,
      'reasons': reasons,
      'message': gaps.isEmpty
          ? 'Invoice sequence is gapless âœ“'
          : 'Found ${gaps.length} gaps in invoice sequence: $gaps',
    };
  }

  /// Validate that invoice appears only once per return period
  /// 
  /// (except for amended versions, which should be deduplicated first)
  static List<String> findDuplicateInvoices(
    List<Map<String, dynamic>> invoices,
  ) {
    final seen = <String, int>{};
    final duplicates = <String>{};

    for (final inv in invoices) {
      final invNo = inv['invoiceNumber'] as String?;
      if (invNo == null) continue;

      if (seen.containsKey(invNo)) {
        duplicates.add(invNo);
      } else {
        seen[invNo] = 1;
      }
    }

    return duplicates.toList();
  }
}

/// Custom exception for GSTR return period validation
class GstrPeriodException implements Exception {
  final String message;

  GstrPeriodException(this.message);

  @override
  String toString() => 'GSTR Period Validation Error: $message';
}

/// GSTR-1 Compliance Audit Report
class GstrComplianceReport {
  final bool isPeriodValid;
  final bool areInvoicesDeduped;
  final bool isSequenceGapless;
  final bool hasNoDuplicates;
  final List<String> issues;

  GstrComplianceReport({
    required this.isPeriodValid,
    required this.areInvoicesDeduped,
    required this.isSequenceGapless,
    required this.hasNoDuplicates,
    required this.issues,
  });

  bool get isFullyCompliant =>
      isPeriodValid &&
      areInvoicesDeduped &&
      isSequenceGapless &&
      hasNoDuplicates;

  String get summary {
    if (isFullyCompliant) {
      return 'GSTR-1 Compliance: PASS âœ“ All checks passed.';
    }
    return 'GSTR-1 Compliance: FAIL âœ— Found ${issues.length} issue(s):\n${issues.join('\n')}';
  }
}
