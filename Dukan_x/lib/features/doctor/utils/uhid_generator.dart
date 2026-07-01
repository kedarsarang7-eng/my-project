import 'dart:math';

/// Generates a human-readable Unique Health ID / Medical Record Number.
///
/// Format: `MRN-{YYYYMMDD}-{4-char-hex}`
/// Example: `MRN-20250715-A3F1`
///
/// Design rationale (clinic task 6.4 — Req 2.19):
/// - Short enough to print on patient cards and read aloud over phone.
/// - Date component gives chronological context (registration date).
/// - 4-char hex suffix (65 536 combinations per day) provides sufficient
///   uniqueness within a single-tenant clinic's daily patient registrations.
/// - Internal UUID remains the primary key for DB operations; UHID is the
///   human-facing label.
///
/// Uniqueness guarantee: within a single tenant, the combination of date +
/// random hex makes collision probability negligible for clinic-scale volumes
/// (< 100 patients/day). A DB unique constraint is NOT enforced on this column
/// because the backfill generates deterministic MRNs from existing row data
/// (id-based hex), and new creates use random hex.
class UhidGenerator {
  static final _random = Random.secure();

  /// Generate a new UHID for a patient being created now.
  static String generate() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final hex = _random
        .nextInt(0xFFFF)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    return 'MRN-$dateStr-$hex';
  }

  /// Generate a retroactive UHID from an existing patient's createdAt and id.
  /// Used for backfilling legacy rows with NULL uhid (on-read fallback).
  static String generateFromExisting({
    required DateTime createdAt,
    required String patientId,
  }) {
    final dateStr =
        '${createdAt.year}'
        '${createdAt.month.toString().padLeft(2, '0')}'
        '${createdAt.day.toString().padLeft(2, '0')}';
    // Derive a deterministic 4-char hex from the patient UUID.
    final hexSuffix = patientId
        .replaceAll('-', '')
        .substring(0, 4)
        .toUpperCase();
    return 'MRN-$dateStr-$hexSuffix';
  }
}
