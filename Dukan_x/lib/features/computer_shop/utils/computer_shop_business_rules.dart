// Computer shop — domain rules (clause 2.16 of `bugfix.md`).
//
// Owns the job-card lifecycle for service / repair work plus the AMC
// (annual maintenance contract) renewal-window check.

enum ComputerJobStatus {
  intake,
  diagnosis,
  partsOrdered,
  underRepair,
  qa,
  ready,
  delivered,
  cancelled,
}

class ComputerShopBusinessRules {
  ComputerShopBusinessRules._();

  /// True iff [next] is a legal lifecycle transition from [current].
  /// Cancelled is a terminal sink reachable from any pre-delivery state.
  static bool isValidJobTransition(
    ComputerJobStatus current,
    ComputerJobStatus next,
  ) {
    if (current == next) return false;
    if (current == ComputerJobStatus.delivered) return false;
    if (current == ComputerJobStatus.cancelled) return false;
    if (next == ComputerJobStatus.cancelled) return true;
    return _allowed[current]?.contains(next) ?? false;
  }

  /// AMC renewal window: an AMC is "due for renewal" if expiry is within
  /// [windowDays] of [now]. Past-due contracts also report as due.
  static bool isAmcDue(DateTime expiry, DateTime now, {int windowDays = 30}) {
    final cutoff = now.add(Duration(days: windowDays));
    return !expiry.isAfter(cutoff);
  }

  static const Map<ComputerJobStatus, Set<ComputerJobStatus>> _allowed = {
    ComputerJobStatus.intake: {ComputerJobStatus.diagnosis},
    ComputerJobStatus.diagnosis: {
      ComputerJobStatus.partsOrdered,
      ComputerJobStatus.underRepair,
    },
    ComputerJobStatus.partsOrdered: {ComputerJobStatus.underRepair},
    ComputerJobStatus.underRepair: {
      ComputerJobStatus.qa,
      ComputerJobStatus.partsOrdered,
    },
    ComputerJobStatus.qa: {ComputerJobStatus.ready},
    ComputerJobStatus.ready: {ComputerJobStatus.delivered},
    ComputerJobStatus.delivered: {},
    ComputerJobStatus.cancelled: {},
  };
}
