import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// FollowUp Status
enum FollowUpStatus {
  pending, // Follow-up scheduled but not yet due
  due, // Follow-up is due today or past
  scheduled, // Appointment created for this follow-up
  completed, // Patient visited
  missed, // Patient didn't show up
}

/// FollowUp Model - Derived from Prescription.nextVisitDate
class FollowUpModel {
  final String prescriptionId;
  final String visitId;
  final String patientId;
  final String? patientName;
  final String doctorId;
  final DateTime followUpDate;
  final String? reason;
  final FollowUpStatus status;

  FollowUpModel({
    required this.prescriptionId,
    required this.visitId,
    required this.patientId,
    this.patientName,
    required this.doctorId,
    required this.followUpDate,
    this.reason,
    this.status = FollowUpStatus.pending,
  });

  /// Check if this follow-up is due
  bool get isDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return followUpDate.isBefore(today.add(const Duration(days: 1)));
  }

  /// Check if follow-up is overdue
  bool get isOverdue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return followUpDate.isBefore(today);
  }

  /// Days until follow-up (negative if overdue)
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return followUpDate.difference(today).inDays;
  }

  Map<String, dynamic> toMap() => {
    'prescriptionId': prescriptionId,
    'visitId': visitId,
    'patientId': patientId,
    'patientName': patientName,
    'doctorId': doctorId,
    'followUpDate': followUpDate.toIso8601String(),
    'reason': reason,
    'status': status.name,
  };
}

/// FollowUp Repository - Derives follow-ups from Prescription.nextVisitDate
///
/// This approach avoids adding a new table and uses existing prescription data.
/// The "status" is computed based on whether a subsequent visit exists.
class FollowUpRepository {
  final AppDatabase _db;

  FollowUpRepository(this._db);

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// Get all upcoming follow-ups for a doctor
  Future<List<FollowUpModel>> getUpcomingFollowUps(String doctorId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Query prescriptions with nextVisitDate >= today
    final prescriptions = await _db
        .customSelect(
          '''
      SELECT 
        p.id as prescription_id,
        p.visit_id,
        p.patient_id,
        p.doctor_id,
        p.next_visit_date,
        p.advice,
        pt.name as patient_name
      FROM prescriptions p
      LEFT JOIN patients pt ON p.patient_id = pt.id
      WHERE p.doctor_id = ?
        AND p.next_visit_date IS NOT NULL
        AND p.next_visit_date >= ?
        AND p.deleted_at IS NULL
      ORDER BY p.next_visit_date ASC
      LIMIT 50
      ''',
          variables: [
            Variable.withString(doctorId),
            Variable.withDateTime(today),
          ],
        )
        .get();

    return prescriptions.map((row) {
      return FollowUpModel(
        prescriptionId: row.read<String>('prescription_id'),
        visitId: row.read<String>('visit_id'),
        patientId: row.read<String>('patient_id'),
        patientName: row.readNullable<String>('patient_name'),
        doctorId: row.read<String>('doctor_id'),
        followUpDate: row.read<DateTime>('next_visit_date'),
        reason: row.readNullable<String>('advice'),
      );
    }).toList();
  }

  /// Get overdue follow-ups (past nextVisitDate, no subsequent visit)
  Future<List<FollowUpModel>> getOverdueFollowUps(String doctorId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Prescriptions with nextVisitDate < today
    final prescriptions = await _db
        .customSelect(
          '''
      SELECT 
        p.id as prescription_id,
        p.visit_id,
        p.patient_id,
        p.doctor_id,
        p.next_visit_date,
        p.advice,
        pt.name as patient_name
      FROM prescriptions p
      LEFT JOIN patients pt ON p.patient_id = pt.id
      WHERE p.doctor_id = ?
        AND p.next_visit_date IS NOT NULL
        AND p.next_visit_date < ?
        AND p.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM visits v 
          WHERE v.patient_id = p.patient_id 
            AND v.visit_date >= p.next_visit_date
            AND v.deleted_at IS NULL
        )
      ORDER BY p.next_visit_date DESC
      LIMIT 50
      ''',
          variables: [
            Variable.withString(doctorId),
            Variable.withDateTime(today),
          ],
        )
        .get();

    return prescriptions.map((row) {
      return FollowUpModel(
        prescriptionId: row.read<String>('prescription_id'),
        visitId: row.read<String>('visit_id'),
        patientId: row.read<String>('patient_id'),
        patientName: row.readNullable<String>('patient_name'),
        doctorId: row.read<String>('doctor_id'),
        followUpDate: row.read<DateTime>('next_visit_date'),
        reason: row.readNullable<String>('advice'),
        status: FollowUpStatus.missed,
      );
    }).toList();
  }

  /// Get follow-ups due today
  Future<List<FollowUpModel>> getTodaysFollowUps(String doctorId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final prescriptions = await _db
        .customSelect(
          '''
      SELECT 
        p.id as prescription_id,
        p.visit_id,
        p.patient_id,
        p.doctor_id,
        p.next_visit_date,
        p.advice,
        pt.name as patient_name
      FROM prescriptions p
      LEFT JOIN patients pt ON p.patient_id = pt.id
      WHERE p.doctor_id = ?
        AND p.next_visit_date IS NOT NULL
        AND p.next_visit_date >= ?
        AND p.next_visit_date < ?
        AND p.deleted_at IS NULL
      ORDER BY p.next_visit_date ASC
      ''',
          variables: [
            Variable.withString(doctorId),
            Variable.withDateTime(startOfDay),
            Variable.withDateTime(endOfDay),
          ],
        )
        .get();

    return prescriptions.map((row) {
      return FollowUpModel(
        prescriptionId: row.read<String>('prescription_id'),
        visitId: row.read<String>('visit_id'),
        patientId: row.read<String>('patient_id'),
        patientName: row.readNullable<String>('patient_name'),
        doctorId: row.read<String>('doctor_id'),
        followUpDate: row.read<DateTime>('next_visit_date'),
        reason: row.readNullable<String>('advice'),
        status: FollowUpStatus.due,
      );
    }).toList();
  }

  /// Get follow-ups for a specific patient
  Future<List<FollowUpModel>> getPatientFollowUps(String patientId) async {
    final prescriptions = await _db
        .customSelect(
          '''
      SELECT 
        p.id as prescription_id,
        p.visit_id,
        p.patient_id,
        p.doctor_id,
        p.next_visit_date,
        p.advice,
        pt.name as patient_name
      FROM prescriptions p
      LEFT JOIN patients pt ON p.patient_id = pt.id
      WHERE p.patient_id = ?
        AND p.next_visit_date IS NOT NULL
        AND p.deleted_at IS NULL
      ORDER BY p.next_visit_date DESC
      LIMIT 20
      ''',
          variables: [Variable.withString(patientId)],
        )
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return prescriptions.map((row) {
      final followUpDate = row.read<DateTime>('next_visit_date');
      final isOverdue = followUpDate.isBefore(today);

      return FollowUpModel(
        prescriptionId: row.read<String>('prescription_id'),
        visitId: row.read<String>('visit_id'),
        patientId: row.read<String>('patient_id'),
        patientName: row.readNullable<String>('patient_name'),
        doctorId: row.read<String>('doctor_id'),
        followUpDate: followUpDate,
        reason: row.readNullable<String>('advice'),
        status: isOverdue ? FollowUpStatus.missed : FollowUpStatus.pending,
      );
    }).toList();
  }

  /// Get follow-up count for dashboard badge
  Future<int> getDueFollowUpCount(String doctorId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfTomorrow = startOfDay.add(const Duration(days: 2));

    final result = await _db
        .customSelect(
          '''
      SELECT COUNT(*) as count
      FROM prescriptions p
      WHERE p.doctor_id = ?
        AND p.next_visit_date IS NOT NULL
        AND p.next_visit_date >= ?
        AND p.next_visit_date < ?
        AND p.deleted_at IS NULL
      ''',
          variables: [
            Variable.withString(doctorId),
            Variable.withDateTime(startOfDay),
            Variable.withDateTime(endOfTomorrow),
          ],
        )
        .getSingle();

    return result.read<int>('count');
  }

  /// Stream of upcoming follow-ups for reactive UI
  Stream<List<FollowUpModel>> watchUpcomingFollowUps(String doctorId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return (_db.select(_db.prescriptions)
          ..where(
            (p) =>
                p.doctorId.equals(doctorId) &
                p.nextVisitDate.isBiggerOrEqualValue(today) &
                p.deletedAt.isNull(),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.nextVisitDate)])
          ..limit(50))
        .watch()
        .asyncMap((prescriptions) async {
          // Fetch patient names for all prescriptions
          final followUps = <FollowUpModel>[];
          for (final p in prescriptions) {
            if (p.nextVisitDate == null) continue;

            final patient = await (_db.select(
              _db.patients,
            )..where((pt) => pt.id.equals(p.patientId))).getSingleOrNull();

            followUps.add(
              FollowUpModel(
                prescriptionId: p.id,
                visitId: p.visitId,
                patientId: p.patientId,
                patientName: patient?.name,
                doctorId: p.doctorId ?? p.userId,
                followUpDate: p.nextVisitDate!,
                reason: p.advice,
              ),
            );
          }
          return followUps;
        });
  }
}
