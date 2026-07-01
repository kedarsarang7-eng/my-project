// Pharmacy — domain rules (clause 2.16 of `bugfix.md`).
//
// Owns batch + expiry checks and the schedule-H/H1/X dispensing rules
// that drive whether a sale is allowed without a prescription.

enum DrugSchedule { otc, h, h1, x }

class PharmacyBusinessRules {
  PharmacyBusinessRules._();

  /// True iff [batch]'s expiry is on or after [today]. Same-day expiry
  /// is still dispensable per pharmacist convention.
  static bool isBatchUsable({
    required DateTime expiryDate,
    required DateTime today,
  }) {
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return !exp.isBefore(now);
  }

  /// Expiring-soon flag: true when [expiryDate] is within [windowDays] of
  /// [today] (or already past). Drives the orange/red highlight in stock
  /// lists.
  static bool isExpiringSoon({
    required DateTime expiryDate,
    required DateTime today,
    int windowDays = 90,
  }) {
    final cutoff = today.add(Duration(days: windowDays));
    return !expiryDate.isAfter(cutoff);
  }

  /// True iff a sale of [schedule] is allowed without a recorded
  /// prescription. OTC: yes. H/H1/X: no.
  static bool canDispenseWithoutPrescription(DrugSchedule schedule) {
    return schedule == DrugSchedule.otc;
  }

  /// True iff a sale of [schedule] requires the prescription to be
  /// retained on-file by the pharmacy (Schedule H1 and X).
  static bool requiresPrescriptionRetention(DrugSchedule schedule) {
    return schedule == DrugSchedule.h1 || schedule == DrugSchedule.x;
  }
}
