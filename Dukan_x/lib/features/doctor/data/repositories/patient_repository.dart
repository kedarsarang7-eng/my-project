import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/session/owner_id_resolver.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../models/patient_model.dart'; // Corrected Path
import '../../services/patient_access_logger.dart';
import '../../utils/uhid_generator.dart';

class PatientRepository {
  final AppDatabase _db;
  final SyncManager _syncManager;

  /// Optional session override for tests. In production this is null and the
  /// shared [resolveOwnerId] falls back to the registered [SessionManager]
  /// singleton (the same owner-id source `clinic_billing_service` uses).
  final SessionManager? _session;

  /// PHI access logger — records every patient data read/write for audit
  /// compliance (clinic task 5.3 — Req 2.11).
  late final PatientAccessLogger _accessLogger;

  PatientRepository({
    required AppDatabase db,
    required SyncManager syncManager,
    SessionManager? session,
  }) : _db = db,
       _syncManager = syncManager,
       _session = session {
    _accessLogger = PatientAccessLogger(db: _db);
  }

  /// Create a new patient (Offline-First)
  Future<void> createPatient(PatientModel patient) async {
    try {
      // Fail-safe tenant attribution: resolve the real owner id BEFORE any
      // write. If the owner id is missing the resolver throws and the write is
      // blocked — never bucketed under 'SYSTEM'.
      final ownerId = resolveOwnerId(
        session: _session,
        operation: 'create patient',
      );

      // Generate a human-readable UHID/MRN if not already set (Req 2.19).
      final uhid = patient.uhid ?? UhidGenerator.generate();
      patient.uhid = uhid;

      // 1. Insert into Local Database
      await _db
          .into(_db.patients)
          .insert(
            PatientsCompanion.insert(
              id: patient.id,
              userId: ownerId,
              name: patient.name,
              phone: Value(patient.phone),
              age: Value(patient.age),
              gender: Value(patient.gender),
              bloodGroup: Value(patient.bloodGroup),
              address: Value(patient.address),
              qrToken: Value(patient.qrToken),
              chronicConditions: Value(patient.chronicConditions),
              allergies: Value(patient.allergies),
              consent: Value(patient.consent),
              createdAt: patient.createdAt,
              updatedAt: patient.updatedAt,
              isSynced: const Value(false),
            ),
          );

      // Persist the UHID column (added in v49 migration). Since PatientsCompanion.insert
      // may not yet have the `uhid` field until build_runner regenerates, we persist
      // it with a direct UPDATE to guarantee the value is written regardless.
      await _db.customStatement('UPDATE patients SET uhid = ? WHERE id = ?', [
        uhid,
        patient.id,
      ]);

      // Persist DOB column (added in v50 migration). Same dynamic-write pattern
      // as uhid until build_runner regenerates `PatientsCompanion`.
      if (patient.dateOfBirth != null) {
        // Drift stores DateTimeColumn as seconds since epoch (INTEGER).
        final dobEpoch = patient.dateOfBirth!.millisecondsSinceEpoch ~/ 1000;
        await _db.customStatement(
          'UPDATE patients SET date_of_birth = ? WHERE id = ?',
          [dobEpoch, patient.id],
        );
      }

      // 2. Queue for Sync
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: ownerId,
          operationType: SyncOperationType.create,
          targetCollection: 'patients',
          documentId: patient.id,
          payload: patient.toMap(),
          priority: 1,
        ),
      );

      // 3. Log PHI access (Req 2.11) — append-only, never blocks the write.
      await _accessLogger.logAccess(
        patientId: patient.id,
        userId: ownerId,
        accessType: PatientAccessType.write,
        description: 'created patient',
      );
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to create patient',
      );
      rethrow;
    }
  }

  /// Update a patient
  Future<void> updatePatient(PatientModel patient) async {
    try {
      final ownerId = resolveOwnerId(
        session: _session,
        operation: 'update patient',
      );
      final now = DateTime.now();
      patient.updatedAt = now;

      await (_db.update(
        _db.patients,
      )..where((t) => t.id.equals(patient.id))).write(
        PatientsCompanion(
          name: Value(patient.name),
          phone: Value(patient.phone),
          age: Value(patient.age),
          gender: Value(patient.gender),
          bloodGroup: Value(patient.bloodGroup),
          address: Value(patient.address),
          qrToken: Value(patient.qrToken),
          chronicConditions: Value(patient.chronicConditions),
          allergies: Value(patient.allergies),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: ownerId,
          operationType: SyncOperationType.update,
          targetCollection: 'patients',
          documentId: patient.id,
          payload: patient.toMap(),
          priority: 1,
        ),
      );
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to update patient',
      );
      rethrow;
    }
  }

  /// Get patient by ID
  Future<PatientModel?> getPatientById(String id) async {
    final row = await (_db.select(
      _db.patients,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final model = _mapToModel(row);

    // Log PHI read access (Req 2.11) — best-effort, never blocks the read.
    // Resolve userId safely; if no session is available the log is skipped
    // (access logging must not prevent data retrieval).
    try {
      final userId = resolveOwnerId(
        session: _session,
        operation: 'read patient (access log)',
      );
      await _accessLogger.logAccess(
        patientId: id,
        userId: userId,
        accessType: PatientAccessType.read,
        description: 'viewed patient details',
      );
    } catch (_) {
      // Owner not available — skip logging rather than blocking the read.
    }

    return model;
  }

  /// Search patients by name or phone
  Future<List<PatientModel>> searchPatients(String query) async {
    final rows = await (_db.select(
      _db.patients,
    )..where((t) => t.name.contains(query) | t.phone.contains(query))).get();
    return rows.map((row) => _mapToModel(row)).toList();
  }

  /// Get patient by QR Token
  Future<PatientModel?> getPatientByQrToken(String token) async {
    final row = await (_db.select(
      _db.patients,
    )..where((t) => t.qrToken.equals(token))).getSingleOrNull();
    if (row == null) return null;
    return _mapToModel(row);
  }

  /// Watch all patients
  Stream<List<PatientModel>> watchAllPatients() {
    return (_db.select(_db.patients)..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .watch()
        .map((rows) => rows.map((row) => _mapToModel(row)).toList());
  }

  PatientModel _mapToModel(PatientEntity row) {
    // NOTE: The `uhid` column was added to the Patients table definition (v49)
    // but `PatientEntity` won't expose it until `dart run build_runner build` is
    // re-run. Until then, we read uhid via the getter if available, otherwise null.
    // After codegen, replace the try/catch with a direct `row.uhid` access.
    String? uhid;
    try {
      uhid = (row as dynamic).uhid as String?;
    } catch (_) {
      // Field not yet in generated code — will be available after build_runner.
    }

    // dateOfBirth (v50) — same dynamic access pattern until codegen runs.
    DateTime? dateOfBirth;
    try {
      dateOfBirth = (row as dynamic).dateOfBirth as DateTime?;
    } catch (_) {
      // Field not yet in generated code — will be available after build_runner.
    }

    return PatientModel(
      id: row.id,
      name: row.name,
      phone: row.phone,
      age: row.age,
      gender: row.gender,
      bloodGroup: row.bloodGroup,
      address: row.address,
      qrToken: row.qrToken,
      chronicConditions: row.chronicConditions,
      allergies: row.allergies,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isSynced: row.isSynced,
      consent: row.consent,
      uhid: uhid,
      dateOfBirth: dateOfBirth,
    );
  }
}
