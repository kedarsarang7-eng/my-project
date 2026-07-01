import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../models/doctor_profile_model.dart';

class DoctorRepository {
  final AppDatabase _db;
  final SyncManager _syncManager;

  DoctorRepository({required AppDatabase db, required SyncManager syncManager})
    : _db = db,
      _syncManager = syncManager;

  /// Create or Update Profile
  Future<void> saveProfile(DoctorProfileModel profile) async {
    try {
      await _db
          .into(_db.doctorProfiles)
          .insert(
            DoctorProfilesCompanion.insert(
              id: profile.id,
              vendorId: profile.vendorId,
              specialization: Value(profile.specialization),
              licenseNumber: Value(profile.licenseNumber),
              qualification: Value(profile.qualification),
              clinicName: Value(profile.clinicName),
              consultationFee: Value(profile.consultationFee),
              createdAt: profile.createdAt,
            ),
            mode: InsertMode.insertOrReplace,
          );

      // Sync
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: profile.vendorId,
          operationType:
              SyncOperationType.update, // Upsert is effectively update
          targetCollection: 'doctor_profiles',
          documentId: profile.id,
          payload: profile.toMap(),
          priority: 1,
        ),
      );
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to save doctor profile',
      );
      rethrow;
    }
  }

  /// Get Profile by Vendor ID (User ID)
  Future<DoctorProfileModel?> getProfileByVendorId(String vendorId) async {
    final row = await (_db.select(
      _db.doctorProfiles,
    )..where((t) => t.vendorId.equals(vendorId))).getSingleOrNull();
    if (row == null) return null;
    return _mapToModel(row);
  }

  /// Get All Doctors (For Admin/Selection)
  Future<List<DoctorProfileModel>> getAllDoctors() async {
    final rows = await _db.select(_db.doctorProfiles).get();
    return rows.map((r) => _mapToModel(r)).toList();
  }

  DoctorProfileModel _mapToModel(DoctorProfileEntity row) {
    return DoctorProfileModel(
      id: row.id,
      vendorId: row.vendorId,
      specialization: row.specialization,
      licenseNumber: row.licenseNumber,
      qualification: row.qualification,
      clinicName: row.clinicName,
      consultationFee: row.consultationFee,
      createdAt: row.createdAt,
    );
  }

  /// Link Patient to Doctor
  Future<void> linkPatient(String patientId, String doctorId) async {
    // Check if link exists
    final exists =
        await (_db.select(_db.patientDoctorLinks)..where(
              (t) =>
                  t.patientId.equals(patientId) & t.doctorId.equals(doctorId),
            ))
            .getSingleOrNull();

    if (exists != null) return; // Already linked

    await _db
        .into(_db.patientDoctorLinks)
        .insert(
          PatientDoctorLinksCompanion.insert(
            id: '${patientId}_$doctorId', // Composite ID or random UUID
            patientId: patientId,
            doctorId: doctorId,
            linkedAt: DateTime.now(),
            status: const Value('ACTIVE'),
          ),
        );

    // Sync logic for link?
    // Usually links need to sync so patient sees doctor in their app.
    // For now, local only or assume broad sync.
  }
}
