// Auto parts — domain rules (clause 2.16 of `bugfix.md`).
//
// Centralises the per-vertical formulas the auto-parts module relies on so
// they live in one auditable place. Today the module owns one signature
// workflow: the job-card lifecycle. Formulas are intentionally pure so
// they can be unit-tested without UI plumbing.

import 'package:decimal/decimal.dart';
import '../../../core/accounting/money_math.dart';

/// Documented job-card statuses, in flow order. Any new status MUST be
/// inserted in the right slot so callers can reason about progress.
enum JobCardStatus {
  intake,
  diagnosis,
  inProgress,
  waitingParts,
  qa,
  completed,
  delivered,
  cancelled,
}

class AutoPartsBusinessRules {
  AutoPartsBusinessRules._();

  /// True iff [next] is a legal transition from [current] in the job-card
  /// lifecycle. Cancelled is a terminal sink reachable from any pre-
  /// delivery state. Delivered is a terminal sink reachable only from
  /// completed. QA cannot be skipped once a card has parts in progress.
  static bool isValidTransition(JobCardStatus current, JobCardStatus next) {
    if (current == next) return false;
    if (current == JobCardStatus.delivered) return false;
    if (current == JobCardStatus.cancelled) return false;
    if (next == JobCardStatus.cancelled) return true;
    return _allowed[current]?.contains(next) ?? false;
  }

  /// Job-card grand total = labour + parts subtotal − discount + tax.
  /// All inputs are paise-friendly doubles; output is rounded half-up to
  /// paise via `MoneyMath` so totals never drift on aggregation.
  static double computeJobCardTotal({
    required double labourCharges,
    required Iterable<double> partsLineTotals,
    double discount = 0,
    double taxAmount = 0,
  }) {
    final partsSubtotal = MoneyMath.addAll(partsLineTotals);
    final gross =
        partsSubtotal +
        Decimal.parse(labourCharges.toString()) -
        Decimal.parse(discount.toString()) +
        Decimal.parse(taxAmount.toString());
    return MoneyMath.roundTo2(gross).toDouble();
  }

  static const Map<JobCardStatus, Set<JobCardStatus>> _allowed = {
    JobCardStatus.intake: {JobCardStatus.diagnosis},
    JobCardStatus.diagnosis: {
      JobCardStatus.inProgress,
      JobCardStatus.waitingParts,
    },
    JobCardStatus.waitingParts: {JobCardStatus.inProgress},
    JobCardStatus.inProgress: {JobCardStatus.qa, JobCardStatus.waitingParts},
    JobCardStatus.qa: {JobCardStatus.completed},
    JobCardStatus.completed: {JobCardStatus.delivered},
    JobCardStatus.delivered: {},
    JobCardStatus.cancelled: {},
  };
}
