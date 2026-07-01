// ============================================================================
// DRUG LICENSE SERVICE — tenant-level persistence (Requirement 14)
// ============================================================================
// Reads and writes the pharmacy tenant's Drug License Number.
//
// STORAGE DECISION (Requirement 4 — no schema changes):
//   The value is persisted inside the EXISTING per-tenant settings store — the
//   `business_settings` Drift table (cloud entity `business_settings`) — using
//   the EXISTING `setting_value` column under a new setting KEY
//   (`pharmacy_drug_license_number`). Adding a settings key writes only data
//   into existing columns; it adds/renames/retypes NO table, column, attribute,
//   key, or index, so it requires no schema migration and no written approval.
//   The business/tenant profile model (`VendorProfile`, `Business`) carries no
//   attribute suited to a drug license number, so the generic settings store —
//   purpose-built for arbitrary per-tenant configuration such as `currency` and
//   `invoice_prefix` — is the appropriate existing home.
//
// All reads/writes are tenant-scoped through `TenantScope` (Requirement 1): the
// active tenantId is the settings `userId`, so one tenant can never read or
// mutate another tenant's drug license number.
//
// Pharmacy-scoped service: only pharmacy code paths use it; the other 18
// verticals are untouched (Requirement 5.3).
// ============================================================================

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/rid_generator.dart';
import '../utils/drug_license.dart';
import '../utils/tenant_scope.dart';

/// Outcome of attempting to save a Drug License Number.
class DrugLicenseSaveResult {
  /// True when the value passed validation and was persisted.
  final bool saved;

  /// The persisted value when [saved]; otherwise the unchanged prior value
  /// (which may be `null` when none was configured) so callers can retain it.
  final String? value;

  /// A length-constraint message when rejected (R14.4); otherwise `null`.
  final String? error;

  const DrugLicenseSaveResult.success(String this.value)
    : saved = true,
      error = null;

  const DrugLicenseSaveResult.rejected({
    required this.value,
    required String this.error,
  }) : saved = false;
}

/// Persists and resolves the tenant-level Drug License Number.
class DrugLicenseService {
  /// Settings key under which the value is stored in `business_settings`.
  static const String settingKey = 'pharmacy_drug_license_number';

  final AppDatabase _db;
  final TenantScope _tenantScope;
  final RidGenerator _ridGenerator;

  /// Creates the service.
  ///
  /// Dependencies default to the app's DI-registered singletons and are
  /// injectable purely to keep the service unit-testable.
  DrugLicenseService({
    AppDatabase? db,
    TenantScope? tenantScope,
    RidGenerator? ridGenerator,
  }) : _db = db ?? sl<AppDatabase>(),
       _tenantScope = tenantScope ?? TenantScope(),
       _ridGenerator = ridGenerator ?? RidGenerator();

  /// Returns the configured Drug License Number for the active tenant, or
  /// `null` when none is configured (R14.3 — absence is a normal state).
  ///
  /// Throws [TenantScopeError] when no active tenant can be resolved (R1.3).
  Future<String?> getDrugLicenseNumber() async {
    final tenantId = _tenantScope.require();
    final row =
        await (_db.select(_db.businessSettings)
              ..where((t) => t.userId.equals(tenantId))
              ..where((t) => t.settingKey.equals(settingKey))
              ..where((t) => t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    final value = row?.settingValue?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// Validates and persists [input] as the active tenant's Drug License Number.
  ///
  /// On success the trimmed value is stored and returned. On failure (empty or
  /// longer than 50 characters, or non-alphanumeric) nothing is written, the
  /// previously saved value is left unchanged and returned, and a
  /// length-constraint message is provided (R14.4).
  ///
  /// Throws [TenantScopeError] when no active tenant can be resolved (R1.3).
  Future<DrugLicenseSaveResult> setDrugLicenseNumber(String? input) async {
    final tenantId = _tenantScope.require();

    final validation = DrugLicense.validate(input);
    if (!validation.isValid) {
      // Reject without mutating: retain the previously saved value (R14.4).
      final prior = await getDrugLicenseNumber();
      return DrugLicenseSaveResult.rejected(
        value: prior,
        error: validation.error ?? DrugLicense.lengthConstraintMessage,
      );
    }

    final value = validation.value!;
    final now = DateTime.now();

    final existing =
        await (_db.select(_db.businessSettings)
              ..where((t) => t.userId.equals(tenantId))
              ..where((t) => t.settingKey.equals(settingKey))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.businessSettings)
          .insert(
            BusinessSettingsCompanion.insert(
              id: _ridGenerator.generate(tenantId),
              userId: tenantId,
              settingKey: settingKey,
              settingValue: Value(value),
              createdAt: now,
              updatedAt: now,
              tenantId: Value(tenantId),
              syncStatus: const Value('pending'),
            ),
          );
    } else {
      await (_db.update(
        _db.businessSettings,
      )..where((t) => t.id.equals(existing.id))).write(
        BusinessSettingsCompanion(
          settingValue: Value(value),
          updatedAt: Value(now),
          deletedAt: const Value(null),
          syncStatus: const Value('pending'),
        ),
      );
    }

    return DrugLicenseSaveResult.success(value);
  }
}
