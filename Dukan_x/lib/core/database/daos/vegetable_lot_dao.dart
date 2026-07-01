import 'package:drift/drift.dart';

import '../app_database.dart';
import '../../utils/rid_generator.dart';

/// Data Access Object for the [VegetableLots] table.
///
/// Handles validation (Requirement 2.4) and net-weight derivation
/// (Requirement 2.3) before persisting a lot. IDs are generated using the
/// shared RID pattern (Requirement 2.8).
class VegetableLotDao {
  final AppDatabase _db;

  VegetableLotDao(this._db);

  /// Insert a new vegetable lot after validation.
  ///
  /// Returns a [LotInsertResult] — either success with the generated RID, or
  /// failure with a human-readable error identifying the invalid field.
  ///
  /// Validation rules (Requirement 2.4):
  /// - grossWeight must be >= 0
  /// - tareWeight must be >= 0
  /// - rate must be >= 0
  /// - grossWeight must be >= tareWeight
  ///
  /// On success (Requirement 2.3):
  /// - netWeight is set to grossWeight − tareWeight
  /// - ID is generated via the RID pattern (Requirement 2.8)
  /// - Status defaults to 'ARRIVED'
  Future<LotInsertResult> insertLot({
    required String userId,
    required String owningFarmerId,
    required double grossWeight,
    required double tareWeight,
    required int rate,
    required String grade,
    String? vehicleNumber,
    DateTime? arrivalDate,
  }) async {
    // --- Validation (Requirement 2.4) ---

    if (grossWeight < 0) {
      return const LotInsertResult.failure(
        'Invalid weight: grossWeight must not be negative',
      );
    }

    if (tareWeight < 0) {
      return const LotInsertResult.failure(
        'Invalid weight: tareWeight must not be negative',
      );
    }

    if (rate < 0) {
      return const LotInsertResult.failure(
        'Invalid rate: rate must not be negative',
      );
    }

    if (grossWeight < tareWeight) {
      return const LotInsertResult.failure(
        'Invalid weight: grossWeight must be greater than or equal to tareWeight',
      );
    }

    // --- Derivation (Requirement 2.3) ---
    final netWeight = grossWeight - tareWeight;

    // --- ID generation (Requirement 2.8) ---
    final id = RidGenerator.generate(userId);

    final now = DateTime.now();

    // --- Persist ---
    await _db
        .into(_db.vegetableLots)
        .insert(
          VegetableLotsCompanion.insert(
            id: id,
            userId: userId,
            owningFarmerId: owningFarmerId,
            grossWeight: grossWeight,
            tareWeight: tareWeight,
            netWeight: netWeight,
            rate: rate,
            grade: grade,
            vehicleNumber: Value(vehicleNumber),
            arrivalDate: arrivalDate ?? now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return LotInsertResult.success(id);
  }
}

/// Sealed result type for lot insertion — explicit error results, no exceptions.
class LotInsertResult {
  final String? id;
  final String? error;

  bool get isSuccess => id != null;
  bool get isFailure => error != null;

  const LotInsertResult.success(this.id) : error = null;
  const LotInsertResult.failure(this.error) : id = null;
}
