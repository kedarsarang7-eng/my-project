// Clinic — domain rules (clause 2.16 of `bugfix.md`).
//
// Owns the appointment slot grid and per-doctor token allocation. Pure
// helpers so they can be unit-tested without DB or UI plumbing.

class ClinicBusinessRules {
  ClinicBusinessRules._();

  /// Token allocation: tokens are assigned in arrival order within a
  /// doctor + date partition. The next token for [doctorId] on [date] is
  /// `currentMax + 1`. If [currentMax] is null (no tokens yet) returns 1.
  static int nextToken(int? currentMax) =>
      currentMax == null ? 1 : currentMax + 1;

  /// True when [start] and [end] form a valid appointment slot:
  ///   * end is strictly after start,
  ///   * duration is at least [minMinutes],
  ///   * duration does not exceed [maxMinutes].
  static bool isValidSlot(
    DateTime start,
    DateTime end, {
    int minMinutes = 5,
    int maxMinutes = 120,
  }) {
    if (!end.isAfter(start)) return false;
    final mins = end.difference(start).inMinutes;
    return mins >= minMinutes && mins <= maxMinutes;
  }

  /// True when [a] overlaps [b]. Two slots with the same doctor must not
  /// overlap; back-to-back slots (a.end == b.start) are allowed.
  static bool slotsOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }
}
