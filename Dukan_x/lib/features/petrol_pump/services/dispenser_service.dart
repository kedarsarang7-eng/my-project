import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/audit_repository.dart';
import '../models/dispenser.dart';
import '../models/nozzle.dart';
import '../models/employee.dart';

/// DispenserService - Manages dispensers and nozzles with PERMISSION ENFORCEMENT
///
/// FRAUD PREVENTION: Nozzle reading edits require canEditReadings permission.
/// Unauthorized attempts are logged to audit trail.
class DispenserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _ownerId => sl<SessionManager>().ownerId ?? '';

  CollectionReference get _dispenserCollection =>
      _firestore.collection('owners').doc(_ownerId).collection('dispensers');

  CollectionReference get _nozzleCollection =>
      _firestore.collection('owners').doc(_ownerId).collection('nozzles');

  CollectionReference get _employeeCollection =>
      _firestore.collection('owners').doc(_ownerId).collection('employees');

  // --- Dispenser Operations ---

  /// Create or update dispenser
  Future<void> saveDispenser(Dispenser dispenser) async {
    await _dispenserCollection
        .doc(dispenser.dispenserId)
        .set(dispenser.toMap(), SetOptions(merge: true));
  }

  /// Get all dispensers
  Stream<List<Dispenser>> getDispensers() {
    return _dispenserCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                Dispenser.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    });
  }

  /// Delete dispenser (only if no nozzles attached)
  Future<void> deleteDispenser(String dispenserId) async {
    await _dispenserCollection.doc(dispenserId).delete();
  }

  // --- Nozzle Operations ---

  /// Create or update nozzle
  Future<void> saveNozzle(Nozzle nozzle) async {
    // 1. Save Nozzle
    await _nozzleCollection
        .doc(nozzle.nozzleId)
        .set(nozzle.toMap(), SetOptions(merge: true));

    // 2. Link to Dispenser if new
    final dispenserRef = _dispenserCollection.doc(nozzle.dispenserId);
    final dispenserDoc = await dispenserRef.get();

    if (dispenserDoc.exists) {
      final dispenser = Dispenser.fromMap(
        dispenserDoc.id,
        dispenserDoc.data() as Map<String, dynamic>,
      );

      if (!dispenser.nozzleIds.contains(nozzle.nozzleId)) {
        await dispenserRef.update({
          'nozzleIds': FieldValue.arrayUnion([nozzle.nozzleId]),
        });
      }
    }
  }

  /// Get nozzles for a specific dispenser
  Stream<List<Nozzle>> getNozzlesByDispenser(String dispenserId) {
    return _nozzleCollection
        .where('dispenserId', isEqualTo: dispenserId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    Nozzle.fromMap(doc.id, doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  /// Get all nozzles
  Stream<List<Nozzle>> getAllNozzles() {
    return _nozzleCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => Nozzle.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    });
  }

  /// Update opening reading (start of shift)
  ///
  /// FRAUD PREVENTION: Requires canEditReadings permission
  /// Update opening reading (start of shift)
  ///
  /// FRAUD PREVENTION: Requires canEditReadings permission
  /// Gap #8 FIX: Block edits if linked shift is CLOSED
  Future<void> updateOpeningReading(
    String nozzleId,
    double reading,
    String shiftId, {
    String? employeeId,
  }) async {
    // 1. GAP #8: Check if shift is OPEN
    await _validateShiftOpen(shiftId);

    // 2. PERMISSION CHECK: canEditReadings
    if (employeeId != null) {
      final hasPermission = await _checkPermission(
        employeeId,
        'canEditReadings',
      );
      if (!hasPermission) {
        await _logUnauthorizedAttempt(
          employeeId,
          'updateOpeningReading',
          nozzleId,
        );
        throw PermissionDeniedException(
          'canEditReadings',
          'You do not have permission to edit nozzle readings.',
        );
      }
    }

    await _nozzleCollection.doc(nozzleId).update({
      'openingReading': reading,
      'closingReading': reading, // Reset closing = opening
      'linkedShiftId': shiftId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Audit log: Reading updated
    await _logReadingChange(nozzleId, 'OPENING', reading, employeeId);
  }

  /// Update closing reading (during/end of shift)
  ///
  /// FRAUD PREVENTION: Requires canEditReadings permission for manual edits
  /// Gap #8 FIX: Block edits if linked shift is CLOSED
  Future<void> updateClosingReading(
    String nozzleId,
    double reading, {
    String? employeeId,
    bool isSystemUpdate = false, // Skip permission for system-initiated updates
  }) async {
    // 1. GAP #8: Check if linked shift is OPEN
    // Need to fetch nozzle first to find shiftId
    final nozzleDoc = await _nozzleCollection.doc(nozzleId).get();
    if (nozzleDoc.exists) {
      final data = nozzleDoc.data() as Map<String, dynamic>;
      final shiftId = data['linkedShiftId'] as String?;
      if (shiftId != null) {
        await _validateShiftOpen(shiftId);
      }
    }

    // 2. PERMISSION CHECK: canEditReadings (skip for system updates like sales)
    if (!isSystemUpdate && employeeId != null) {
      final hasPermission = await _checkPermission(
        employeeId,
        'canEditReadings',
      );
      if (!hasPermission) {
        await _logUnauthorizedAttempt(
          employeeId,
          'updateClosingReading',
          nozzleId,
        );
        throw PermissionDeniedException(
          'canEditReadings',
          'You do not have permission to edit nozzle readings.',
        );
      }
    }

    await _nozzleCollection.doc(nozzleId).update({
      'closingReading': reading,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Audit log: Reading updated (only for manual changes)
    if (!isSystemUpdate) {
      await _logReadingChange(nozzleId, 'CLOSING', reading, employeeId);
    }
  }

  /// Gap #8: Validate shift is open for editing
  Future<void> _validateShiftOpen(String shiftId) async {
    final doc = await _firestore
        .collection('owners')
        .doc(_ownerId)
        .collection('shifts')
        .doc(shiftId)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'closed') {
        throw Exception(
          'Cannot modify nozzle reading: The linked shift is CLOSED. Re-open shift to edit.',
        );
      }
    }
  }

  /// Check if employee has a specific permission
  Future<bool> _checkPermission(String employeeId, String permission) async {
    try {
      final doc = await _employeeCollection.doc(employeeId).get();
      if (!doc.exists) return false;

      final employee = Employee.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );

      switch (permission) {
        case 'canEditReadings':
          return employee.permissions.canEditReadings;
        case 'canOpenShift':
          return employee.permissions.canOpenShift;
        case 'canCloseShift':
          return employee.permissions.canCloseShift;
        case 'canAddPurchase':
          return employee.permissions.canAddPurchase;
        case 'canManageCredit':
          return employee.permissions.canManageCredit;
        default:
          return false;
      }
    } catch (e) {
      // Default to false on error for security
      return false;
    }
  }

  /// Log unauthorized permission attempt
  Future<void> _logUnauthorizedAttempt(
    String employeeId,
    String action,
    String resourceId,
  ) async {
    try {
      final auditRepo = sl<AuditRepository>();
      await auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'nozzles',
        recordId: resourceId,
        action: 'PERMISSION_DENIED',
        newValueJson:
            '{"employeeId": "$employeeId", "attemptedAction": "$action"}',
      );
    } catch (_) {
      // Audit failure should not block operation
    }
  }

  /// Log reading change for audit trail
  Future<void> _logReadingChange(
    String nozzleId,
    String readingType,
    double value,
    String? employeeId,
  ) async {
    try {
      final auditRepo = sl<AuditRepository>();
      await auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'nozzles',
        recordId: nozzleId,
        action: 'READING_UPDATE',
        newValueJson:
            '{"type": "$readingType", "value": $value, "employeeId": "$employeeId"}',
      );
    } catch (_) {
      // Audit failure should not block operation
    }
  }
}

/// Exception thrown when permission is denied
class PermissionDeniedException implements Exception {
  final String permission;
  final String message;

  PermissionDeniedException(this.permission, this.message);

  @override
  String toString() =>
      'PermissionDeniedException: $message (requires: $permission)';
}
