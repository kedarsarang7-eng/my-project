// ============================================================================
// PATIENT ACCESS LOGGER — PHI AUDIT TRAIL (clinic task 5.3 — Req 2.11)
// ============================================================================
//
// Append-only service that records every read/write/update of patient or visit
// data into the [PatientAccessLogs] Drift table. Called from repositories and
// screens to satisfy PHI access-logging requirements.
//
// AT-REST PROTECTION STRATEGY (app-layer scope):
// ─────────────────────────────────────────────────────────────────────────────
// This logger is PART of the governance layer for sensitive PHI columns
// (patients.allergies, patients.chronicConditions, visits.diagnosis,
// visits.notes). The full strategy comprises:
//   1. ACCESS LOGGING (this service) — every PHI access recorded with actor,
//      timestamp, access type, and description.
//   2. CONSENT CAPTURE — the `consent` flag on the patients table records
//      informed consent before PHI is stored.
//   3. ROLE GATING — clinical-role enforcement (task 5.2) restricts who can
//      view diagnosis/private notes.
//   4. FUTURE: Column-level encryption of sensitive fields at rest using a
//      key derived from the owner's credentials, stored in platform keychain.
//      Flagged for Phase 9; the current pass provides audit + consent + role
//      enforcement only.
// ─────────────────────────────────────────────────────────────────────────────
//
// Usage:
//   final logger = PatientAccessLogger(db: appDatabase);
//   await logger.logAccess(
//     patientId: patient.id,
//     userId: currentOwnerId,
//     accessType: PatientAccessType.write,
//     description: 'created patient',
//   );
// ============================================================================

import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// The type of PHI access being logged.
enum PatientAccessType {
  /// Patient data was read (e.g., viewed patient details, loaded visit).
  read,

  /// Patient data was created (e.g., new patient registration).
  write,

  /// Patient data was modified (e.g., updated allergies, saved visit).
  update,
}

/// Logs PHI access events into the append-only [PatientAccessLogs] table.
///
/// This service is intentionally lightweight — it does NOT throw on failure so
/// a logging error never blocks the primary operation. Errors are printed to
/// debug console for observability.
class PatientAccessLogger {
  final AppDatabase _db;

  PatientAccessLogger({required AppDatabase db}) : _db = db;

  /// Record a PHI access event.
  ///
  /// [patientId] — the patient whose data was accessed.
  /// [userId] — the authenticated user performing the access.
  /// [accessType] — read / write / update.
  /// [description] — optional human-readable context (e.g., "viewed visit",
  ///   "created patient", "updated allergies").
  ///
  /// Never throws — access logging must not block the primary operation.
  Future<void> logAccess({
    required String patientId,
    required String userId,
    required PatientAccessType accessType,
    String? description,
  }) async {
    try {
      await _db
          .into(_db.patientAccessLogs)
          .insert(
            PatientAccessLogsCompanion.insert(
              patientId: patientId,
              userId: userId,
              accessType: accessType.name,
              timestamp: DateTime.now(),
              description: Value(description),
            ),
          );
    } catch (e) {
      // Access logging MUST NOT block the primary operation. Log and continue.
      // In production this would go to a structured logger / crashlytics.
      assert(() {
        // ignore: avoid_print
        print('PatientAccessLogger: failed to log access — $e');
        return true;
      }());
    }
  }
}

/// Convenience top-level function for quick access logging from any context
/// that has access to the database instance.
///
/// Example:
///   await logPatientAccess(
///     db: appDb,
///     patientId: 'pat-123',
///     userId: 'usr-456',
///     type: PatientAccessType.read,
///     description: 'viewed patient details',
///   );
Future<void> logPatientAccess({
  required AppDatabase db,
  required String patientId,
  required String userId,
  required PatientAccessType type,
  String? description,
}) async {
  await PatientAccessLogger(db: db).logAccess(
    patientId: patientId,
    userId: userId,
    accessType: type,
    description: description,
  );
}
