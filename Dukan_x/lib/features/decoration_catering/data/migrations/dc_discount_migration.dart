// ============================================================================
// DC DISCOUNT MIGRATION — idempotent absolute-to-percentage conversion
// ============================================================================
// Converts stored absolute discount amounts to `discountPercent` on each DC
// quote record. Idempotent: a second run changes zero records because the
// migration skips any quote that already has `discountPercent` set.
//
// NO DynamoDB schema change is required — `discountPercent` coexists with
// `discountPaisa` on the same item. If a schema change were ever needed, a
// Mini_Approval_Gate would be required per Requirement 1.8.
//
// Usage:
//   final repo = DcRepository();
//   final result = await DcDiscountMigration.run(repo);
//   print('Migrated: ${result.migrated}, Skipped: ${result.skipped}');
//
// Requirements: 10.2, 1.8
// ============================================================================

import 'package:flutter/foundation.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../repositories/dc_repository.dart';

/// Result of a discount migration run.
class DcDiscountMigrationResult {
  /// Number of quotes successfully migrated (discountPercent persisted).
  final int migrated;

  /// Number of quotes skipped (already had discountPercent or no discount).
  final int skipped;

  /// Number of quotes that encountered an error during migration.
  final int errored;

  /// Error details keyed by quote id (only for errored records).
  final Map<String, String> errors;

  const DcDiscountMigrationResult({
    required this.migrated,
    required this.skipped,
    required this.errored,
    this.errors = const {},
  });

  /// Total quotes processed (migrated + skipped + errored).
  int get total => migrated + skipped + errored;

  @override
  String toString() =>
      'DcDiscountMigrationResult(migrated: $migrated, skipped: $skipped, '
      'errored: $errored, total: $total)';
}

/// Idempotent migration that converts absolute discount values on DC quotes
/// to the unified percentage model (`discountPercent`).
///
/// The migration is **callable but not auto-executed**. Invoke via:
/// ```dart
/// final result = await DcDiscountMigration.run(repo);
/// ```
///
/// Idempotency guarantee: if a quote record already has a non-null
/// `discountPercent` field in its stored JSON, the record is skipped. After
/// the first successful run, all subsequent runs produce zero migrations.
class DcDiscountMigration {
  DcDiscountMigration._();

  /// Runs the migration against the provided [repo].
  ///
  /// Steps per quote:
  /// 1. Read raw quote JSON from the API (to inspect `discountPercent` field).
  /// 2. If `discountPercent` is already set (non-null) → skip (idempotent).
  /// 3. If `discountPaisa` is 0 or null → skip (nothing to convert).
  /// 4. If `subtotalPaisa` is 0 or null → skip with error (cannot divide by 0).
  /// 5. Compute: `discountPct = round2(discountPaisa / subtotalPaisa * 100)`.
  /// 6. PUT the computed `discountPercent` back on the quote record.
  ///
  /// Returns a [DcDiscountMigrationResult] with counts.
  static Future<DcDiscountMigrationResult> run(DcRepository repo) async {
    final api = sl<ApiClient>();
    int migrated = 0;
    int skipped = 0;
    int errored = 0;
    final errors = <String, String>{};

    // Fetch all quotes as raw JSON so we can inspect the `discountPercent` field.
    final rawQuotes = await _fetchRawQuotes(api);

    for (final quote in rawQuotes) {
      final id = quote['id'] as String?;
      if (id == null || id.isEmpty) {
        errored++;
        errors['unknown'] = 'Quote record missing id field';
        continue;
      }

      try {
        final migrationAction = _classifyQuote(quote);

        switch (migrationAction) {
          case _MigrationAction.skip:
            skipped++;
            break;

          case _MigrationAction.error:
            errored++;
            errors[id] =
                'subtotalPaisa is 0 or missing; cannot compute '
                'discount percentage (division by zero)';
            break;

          case _MigrationAction.migrate:
            final discountPaisa = (quote['discountPaisa'] as num).toInt();
            final subtotalPaisa = (quote['subtotalPaisa'] as num).toInt();

            // Compute: discountPct = round2(absDiscount / subtotal * 100)
            // Using double arithmetic through DcMoneyMath.round2 which returns
            // the nearest integer — but here we need a percentage (double with
            // ≤2 dp), so we compute it as a double and round to 2 decimal places.
            final discountPct = _computeDiscountPct(
              discountPaisa,
              subtotalPaisa,
            );

            // Persist the computed discountPercent on the quote record.
            final success = await _persistDiscountPercent(api, id, discountPct);
            if (success) {
              migrated++;
              debugPrint(
                '[DcDiscountMigration] Migrated quote "$id": '
                'discountPaisa=$discountPaisa, subtotalPaisa=$subtotalPaisa '
                '→ discountPercent=$discountPct',
              );
            } else {
              errored++;
              errors[id] = 'Failed to persist discountPercent via API';
            }
            break;
        }
      } catch (e) {
        errored++;
        errors[id] = e.toString();
      }
    }

    final result = DcDiscountMigrationResult(
      migrated: migrated,
      skipped: skipped,
      errored: errored,
      errors: errors,
    );

    debugPrint('[DcDiscountMigration] Complete: $result');
    return result;
  }

  // ── Internal helpers ────────────────────────────────────────────────────

  /// Fetches all quotes as raw JSON maps from the API.
  static Future<List<Map<String, dynamic>>> _fetchRawQuotes(
    ApiClient api,
  ) async {
    final res = await api.get('/dc/quotes');
    final raw = res.data?['data'];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  /// Classifies a quote record into a migration action.
  static _MigrationAction _classifyQuote(Map<String, dynamic> quote) {
    // Idempotency check: if discountPercent is already set, skip.
    final existingPct = quote['discountPercent'];
    if (existingPct != null) {
      return _MigrationAction.skip;
    }

    // No absolute discount to convert → skip.
    final discountPaisa = (quote['discountPaisa'] as num?)?.toInt() ?? 0;
    if (discountPaisa == 0) {
      return _MigrationAction.skip;
    }

    // Cannot compute percentage without a subtotal.
    final subtotalPaisa = (quote['subtotalPaisa'] as num?)?.toInt() ?? 0;
    if (subtotalPaisa == 0) {
      return _MigrationAction.error;
    }

    return _MigrationAction.migrate;
  }

  /// Computes the discount percentage from absolute paise values.
  ///
  /// Formula: `discountPct = round2(discountPaisa / subtotalPaisa * 100)`
  /// where round2 rounds to 2 decimal places (half-up).
  ///
  /// The result is a `double` percentage ∈ [0, 100] with ≤ 2 decimal places.
  static double _computeDiscountPct(int discountPaisa, int subtotalPaisa) {
    // Compute as a raw double percentage.
    final rawPct = discountPaisa / subtotalPaisa * 100.0;

    // Round to 2 decimal places (half-up), matching the design doc's
    // `round2(absDiscount / subtotal * 100)` specification.
    // DcMoneyMath.round2 operates on fractional paise → int, but here we need
    // a 2-dp double percentage. We use the standard half-up rounding formula:
    final rounded = (rawPct * 100).roundToDouble() / 100;

    // Clamp to [0, 100] as a safety bound.
    return rounded.clamp(0.0, 100.0);
  }

  /// Persists the computed `discountPercent` on the quote record via PUT.
  ///
  /// Returns `true` on success, `false` on failure.
  static Future<bool> _persistDiscountPercent(
    ApiClient api,
    String quoteId,
    double discountPercent,
  ) async {
    final res = await api.put(
      '/dc/quotes/$quoteId',
      body: {'discountPercent': discountPercent},
    );
    return res.isSuccess;
  }
}

/// Internal classification for migration decision per quote.
enum _MigrationAction { skip, migrate, error }
